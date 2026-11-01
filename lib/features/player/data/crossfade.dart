import 'dart:async';
import 'dart:math' as math;

import '../domain/crossfade_settings.dart';
import '../domain/queue_song.dart';

/// Whether going from [current] to [next] should stay gapless instead of
/// fading: both carry the same real album tag and [next] is the following
/// track number on the same disc. An album name that is just the folder's
/// name (MediaStore's stand-in for untagged files), a missing album, or a
/// missing track number always crossfades.
bool keepsGapless(QueueSong current, QueueSong next) {
  final album = current.taggedAlbum;
  if (album == null || album.toLowerCase() != next.taggedAlbum?.toLowerCase()) {
    return false;
  }
  // Same name, different album ("Greatest Hits" by two artists).
  if (current.albumId != null &&
      next.albumId != null &&
      current.albumId != next.albumId) {
    return false;
  }
  final track = current.trackNumber;
  final nextTrack = next.trackNumber;
  if (track == null || nextTrack == null) return false;
  if ((current.discNumber ?? 1) != (next.discNumber ?? 1)) return false;
  return nextTrack == track + 1;
}

/// How long the fade between [current] and [next] lasts: the setting, but
/// never more than half of either song.
Duration crossfadeLength(Duration setting, Duration current, Duration next) {
  var length = setting;
  for (final song in [current, next]) {
    if (song > Duration.zero && song ~/ 2 < length) length = song ~/ 2;
  }
  return length;
}

/// Equal-power curves: the summed loudness stays even through the fade.
double fadeInGain(double t) => math.sin(t.clamp(0.0, 1.0) * math.pi / 2);
double fadeOutGain(double t) => math.cos(t.clamp(0.0, 1.0) * math.pi / 2);

/// The second player, which plays only the outgoing song's tail.
abstract interface class TailPlayer {
  /// Loads [uri] paused at [position].
  Future<void> load(Uri uri, Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Duration get position;
  bool get playing;

  /// True once audio is coming out (playing and ready).
  bool get started;

  Future<void> dispose();
}

/// What the crossfader needs from the main player.
abstract interface class CrossfadeHost {
  Duration get position;
  bool get playing;

  /// The current song's ReplayGain factor times the sleep timer's fade:
  /// the tail plays at the same loudness the main player did.
  double get outgoingVolume;

  /// Sets the extra factor on the main player's own volume (1 = none).
  Future<void> setRamp(double ramp);

  /// Moves the main player to the next song, at its start.
  Future<void> jumpToNext();
}

/// Runs crossfades between songs.
///
/// About [prepareAhead] before the fade, the tail player loads the
/// current song at the same point and starts, muted, [syncAhead] early,
/// so that it can be lined up with the main player (both play the same
/// audio; one correction seek if they drift apart). At the fade's start
/// the tail player takes over the outgoing song in [handover] and the
/// main player jumps to the next song, then both ramp: the tail out, the
/// main player in.
class Crossfader {
  Crossfader({
    required this.host,
    required TailPlayer Function() tailPlayer,
    this.prepareAhead = const Duration(seconds: 6),
    this.syncAhead = const Duration(milliseconds: 1500),
    this.handover = const Duration(milliseconds: 40),
    this.tick = const Duration(milliseconds: 30),
    DateTime Function()? clock,
  }) : _createTail = tailPlayer,
       _clock = clock ?? DateTime.now;

  final CrossfadeHost host;
  final TailPlayer Function() _createTail;
  final Duration prepareAhead;
  final Duration syncAhead;
  final Duration handover;
  final Duration tick;
  final DateTime Function() _clock;

  TailPlayer? _tail;
  TailPlayer get _tailPlayer => _tail ??= _createTail();

  CrossfadeSettings _settings = crossfadeOff;
  CrossfadeSettings get settings => _settings;
  bool get enabled => _settings.length > Duration.zero;

  /// The planned fade: which song it leaves, and when.
  ({int songId, Duration start, Duration length})? _plan;
  _Phase _phase = _Phase.idle;
  Timer? _ticker;
  DateTime? _fadeStarted;
  Duration _fadePaused = Duration.zero;
  double _tailVolume = 1;

  /// True from the jump until the fade ends: the main player's song change
  /// is ours, not the user's.
  bool get fading => _phase == _Phase.fading;

  /// Song changes made by [jumpToNext] are expected; others cancel.
  bool _jumping = false;
  bool get jumping => _jumping;

  void configure(CrossfadeSettings settings) {
    _settings = settings;
    if (!enabled) unawaited(cancel());
  }

  /// From the main player's position updates. [next] is the song that
  /// would follow by itself (null at the end of the queue, under repeat
  /// one, or when the sleep timer stops at the end of this song).
  void onPosition({
    required QueueSong? current,
    required QueueSong? next,
    required Duration duration,
  }) {
    if (!enabled || current == null || !host.playing) return;
    if (_phase == _Phase.fading || _phase == _Phase.handingOver) return;
    final position = host.position;
    final plan = _plan;
    if (plan != null && plan.songId != current.id) {
      unawaited(cancel());
      return;
    }
    if (plan == null) {
      if (next == null || duration <= Duration.zero) return;
      if (keepsGapless(current, next)) return;
      final length = crossfadeLength(_settings.length, duration, next.duration);
      if (length < const Duration(milliseconds: 500)) return;
      final start = duration - length;
      if (position < start - prepareAhead || position >= start) return;
      _plan = (songId: current.id, start: start, length: length);
      _phase = _Phase.preparing;
      unawaited(_prepare(current, start));
      return;
    }
    if (_phase == _Phase.ready && position >= plan.start - syncAhead) {
      _phase = _Phase.syncing;
      unawaited(_sync());
    }
    if (_phase == _Phase.synced && position >= plan.start) {
      unawaited(_handOver(plan.length));
    }
    // Seeking back out of the planned window cancels.
    if (position < plan.start - prepareAhead - const Duration(seconds: 1)) {
      unawaited(cancel());
    }
  }

  Future<void> _prepare(QueueSong song, Duration start) async {
    final tail = _tailPlayer;
    try {
      await tail.setVolume(0);
      final at = host.position;
      final from = start - syncAhead > at ? start - syncAhead : at;
      await tail.load(song.uri, from);
      if (_phase == _Phase.preparing) _phase = _Phase.ready;
    } on Object {
      await cancel();
    }
  }

  /// Starts the muted tail player alongside the main one and lines it up.
  Future<void> _sync() async {
    final tail = _tailPlayer;
    try {
      // Aim where the main player will be once the tail has started.
      await tail.seek(host.position + const Duration(milliseconds: 120));
      unawaited(tail.play());
      if (!await _waitUntil(() => tail.started)) return await cancel();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_phase != _Phase.syncing) return;
      final drift = host.position - tail.position;
      if (drift.abs() > const Duration(milliseconds: 25)) {
        await tail.seek(tail.position + drift);
        await _waitUntil(() => tail.started);
      }
      if (_phase == _Phase.syncing) _phase = _Phase.synced;
    } on Object {
      await cancel();
    }
  }

  Future<bool> _waitUntil(bool Function() test) async {
    for (var i = 0; i < 50; i++) {
      if (test()) return true;
      if (_phase == _Phase.idle) return false;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return false;
  }

  Future<void> _handOver(Duration length) async {
    _phase = _Phase.handingOver;
    final tail = _tailPlayer;
    _tailVolume = host.outgoingVolume;
    // A short swap between two copies of the same audio.
    final steps = math.max(1, handover.inMilliseconds ~/ 10);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      await Future.wait([
        tail.setVolume(fadeInGain(t) * _tailVolume),
        host.setRamp(fadeOutGain(t)),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    if (_phase != _Phase.handingOver) return;
    _jumping = true;
    try {
      await host.jumpToNext();
    } finally {
      _jumping = false;
    }
    _startFade(length);
  }

  void _startFade(Duration length) {
    _phase = _Phase.fading;
    _fadeStarted = _clock();
    _fadePaused = Duration.zero;
    _ticker?.cancel();
    _ticker = Timer.periodic(tick, (_) => _step(length));
    _step(length);
  }

  void _step(Duration length) {
    final started = _fadeStarted;
    if (started == null) return;
    final elapsed = _clock().difference(started) - _fadePaused;
    final t = elapsed.inMicroseconds / length.inMicroseconds;
    if (t >= 1) {
      unawaited(_finish());
      return;
    }
    unawaited(host.setRamp(fadeInGain(t)));
    unawaited(_tailPlayer.setVolume(fadeOutGain(t) * _tailVolume));
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _ticker = null;
    _fadeStarted = null;
    _plan = null;
    _phase = _Phase.idle;
    await host.setRamp(1);
    await _tail?.stop();
  }

  DateTime? _pausedAt;

  /// The main player paused: the tail (and the fade's clock) pause too.
  Future<void> onPause() async {
    if (_phase == _Phase.idle) return;
    if (_phase != _Phase.fading) return cancel();
    _ticker?.cancel();
    _pausedAt = _clock();
    await _tail?.pause();
  }

  Future<void> onPlay(Duration Function() lengthOf) async {
    final pausedAt = _pausedAt;
    if (_phase != _Phase.fading || pausedAt == null) return;
    _fadePaused += _clock().difference(pausedAt);
    _pausedAt = null;
    await _tail?.play();
    final length = lengthOf();
    _ticker = Timer.periodic(tick, (_) => _step(length));
  }

  /// A manual skip with "crossfade on skip": the tail player takes over
  /// the current song from here while the main player moves on. Returns
  /// false when it doesn't apply (the caller then skips normally).
  Future<bool> skip({
    required QueueSong current,
    required QueueSong? next,
  }) async {
    if (!enabled || !_settings.onSkip || !host.playing || next == null) {
      return false;
    }
    await cancel();
    final length = crossfadeLength(
      _settings.length,
      Duration.zero,
      next.duration,
    );
    final tail = _tailPlayer;
    try {
      _phase = _Phase.syncing;
      await tail.setVolume(0);
      // Start a little ahead, where the main player will be by then.
      await tail.load(
        current.uri,
        host.position + const Duration(milliseconds: 250),
      );
      unawaited(tail.play());
      if (!await _waitUntil(() => tail.started)) {
        await cancel();
        return false;
      }
      _plan = (songId: current.id, start: host.position, length: length);
      await _handOver(length);
      return true;
    } on Object {
      await cancel();
      return false;
    }
  }

  /// Back to a plain single player: stops the tail, full main volume.
  Future<void> cancel() async {
    final wasActive = _phase != _Phase.idle;
    _ticker?.cancel();
    _ticker = null;
    _plan = null;
    _fadeStarted = null;
    _pausedAt = null;
    _phase = _Phase.idle;
    if (!wasActive) return;
    await host.setRamp(1);
    await _tail?.stop();
  }

  Future<void> dispose() async {
    await cancel();
    await _tail?.dispose();
    _tail = null;
  }

  /// The length of the fade in progress (for resuming after a pause).
  Duration get currentLength => _plan?.length ?? _settings.length;

  /// For tests and diagnostics.
  String get phase => _phase.name;
}

enum _Phase { idle, preparing, ready, syncing, synced, handingOver, fading }
