import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/artwork/artwork_cache.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/queue_state_dao.dart';
import '../domain/player.dart';
import '../domain/queue_model.dart';
import '../domain/queue_restore.dart';
import '../domain/queue_song.dart';
import 'play_event_recorder.dart';

/// Owns the single [AudioPlayer] and the queue, and publishes state to the
/// notification, lock screen and media buttons through audio_service.
/// The app talks to it through the [Player] interface.
///
/// Shuffle is our own (docs/PLAN.md §3): the playlist is physically
/// reordered around the current song, never through just_audio's shuffle
/// mode, so the queue always shows the real play order.
class HaraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements Player {
  HaraAudioHandler({
    required this._player,
    required this._recorder,
    required this._artwork,
    this._queueStore,
    Random? random,
  }) : _random = random ?? Random() {
    _subscriptions.addAll([
      _player.playbackEventStream.listen(
        (_) => _broadcastState(),
        onError: (Object _, StackTrace _) => _broadcastState(),
      ),
      _player.playerStateStream.listen(_onPlayerState),
      _player.currentIndexStream.listen(_onIndex),
      _player.positionStream.listen(_onPosition),
      _player.positionDiscontinuityStream.listen(_onDiscontinuity),
    ]);
  }

  /// Notification artwork size in pixels.
  static const _artSize = 384;

  /// "Previous" restarts the song when it has played longer than this.
  static const _restartThreshold = Duration(seconds: 3);

  /// While playing, the saved position is refreshed this often.
  static const _savePositionEvery = Duration(seconds: 5);

  final AudioPlayer _player;
  final PlayEventRecorder _recorder;
  final ArtworkCache _artwork;
  final QueueStateDao? _queueStore;
  final Random _random;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// The queue, including the order it would have without shuffle.
  QueueModel _queue = QueueModel(const []);

  /// [_queue] in play order, matching just_audio's playlist.
  List<QueueSong> _songs = const [];
  RepeatSetting _repeat = RepeatSetting.off;
  PlaySource _source = PlaySource.songs;
  String? _sourceLabel;

  /// Set while the playlist is rebuilt around the current song, when
  /// just_audio's index briefly points at shifting entries.
  bool _rebuilding = false;
  Duration _lastSavedPosition = Duration.zero;

  final _status = StreamController<PlaybackStatus>.broadcast();
  PlaybackStatus _lastStatus = PlaybackStatus.idle;

  /// Configures audio focus and "becoming noisy" (headphones unplugged).
  Future<void> configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _subscriptions.add(session.becomingNoisyEventStream.listen((_) => pause()));
  }

  // Player interface ---------------------------------------------------------

  @override
  Stream<PlaybackStatus> get status async* {
    yield _lastStatus;
    yield* _status.stream;
  }

  @override
  PlaybackStatus get currentStatus => _lastStatus;

  @override
  Stream<Duration> get position => _player.positionStream;

  bool get _shuffled => _queue.shuffled;

  @override
  Future<void> playSongs(
    List<QueueSong> songs, {
    int startIndex = 0,
    required PlaySource source,
    String? sourceLabel,
    bool? shuffle,
  }) async {
    if (songs.isEmpty) return;
    // Even replaying the same song starts a new listen.
    _recorder.trackChanged(null, source: source);
    final start = startIndex.clamp(0, songs.length - 1);
    final shuffled = shuffle ?? _shuffled;
    _queue = QueueModel(songs);
    _source = source;
    _sourceLabel = sourceLabel;
    final index = shuffled ? _queue.shuffle(start, _random) : start;
    _songs = _queue.songs;
    _publishQueue();
    await _player.setAudioSources(
      _sourcesFor(_songs),
      initialIndex: index,
      initialPosition: Duration.zero,
    );
    unawaited(_saveQueue());
    await play();
  }

  @override
  Future<void> togglePlay() => _player.playing ? pause() : play();

  @override
  Future<void> next() => skipToNext();

  @override
  Future<void> previous() => skipToPrevious();

  @override
  Future<void> setShuffle(bool enabled) async {
    final current = _player.currentIndex;
    if (enabled == _shuffled || current == null || _songs.isEmpty) return;
    final newCurrent = enabled
        ? _queue.shuffle(current, _random)
        : _queue.unshuffle(current);
    await _rebuildAround(current, _queue.songs, newCurrent);
    unawaited(_saveQueue());
  }

  @override
  Future<void> setRepeat(RepeatSetting mode) async {
    _repeat = mode;
    await _player.setLoopMode(_loopModeFor(mode));
    _publishStatus();
    unawaited(_saveQueue());
  }

  int get _current => _player.currentIndex ?? 0;

  @override
  Future<void> playNext(List<QueueSong> songs) =>
      _insert(_songs.isEmpty ? 0 : _current + 1, songs);

  @override
  Future<void> addToQueue(List<QueueSong> songs) =>
      _insert(_songs.length, songs);

  Future<void> _insert(int at, List<QueueSong> songs) async {
    if (songs.isEmpty) return;
    if (_songs.isEmpty) {
      await playSongs(songs, source: PlaySource.queue, shuffle: false);
      return;
    }
    await _edit(() async {
      _queue.insert(at, songs);
      await _player.insertAudioSources(at, _sourcesFor(songs));
    });
  }

  @override
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _songs.length || index == _current) return;
    await _edit(() async {
      _queue.removeAt(index);
      await _player.removeAudioSourceAt(index);
    });
  }

  @override
  Future<void> moveInQueue(int from, int to) async {
    final last = _songs.length - 1;
    if (from == to || from < 0 || to < 0 || from > last || to > last) return;
    await _edit(() async {
      _queue.move(from, to);
      await _player.moveAudioSource(from, to);
    });
  }

  @override
  Future<void> clearUpcoming() async {
    final start = _current + 1;
    final end = _songs.length;
    if (start >= end) return;
    await _edit(() async {
      _queue.removeRange(start, end);
      await _player.removeAudioSourceRange(start, end);
    });
  }

  @override
  Future<void> skipTo(int index) => skipToQueueItem(index);

  /// Applies a queue edit to [_queue] and the playlist together. Index
  /// updates are held back until both agree again.
  Future<void> _edit(Future<void> Function() edit) async {
    _rebuilding = true;
    try {
      await edit();
      _songs = _queue.songs;
    } finally {
      _rebuilding = false;
    }
    _publishQueue();
    _publishStatus();
    unawaited(_saveQueue());
  }

  /// Replaces every playlist entry except the current one, so the current
  /// song keeps playing while the order around it changes.
  Future<void> _rebuildAround(
    int current,
    List<QueueSong> newOrder,
    int newCurrent,
  ) async {
    _rebuilding = true;
    try {
      final length = _songs.length;
      if (current + 1 < length) {
        await _player.removeAudioSourceRange(current + 1, length);
      }
      if (current > 0) await _player.removeAudioSourceRange(0, current);
      if (newCurrent > 0) {
        await _player.insertAudioSources(
          0,
          _sourcesFor(newOrder.sublist(0, newCurrent)),
        );
      }
      if (newCurrent + 1 < newOrder.length) {
        await _player.addAudioSources(
          _sourcesFor(newOrder.sublist(newCurrent + 1)),
        );
      }
      _songs = List.unmodifiable(newOrder);
    } finally {
      _rebuilding = false;
    }
    _publishQueue();
    _publishStatus();
  }

  /// Loads the queue saved by the previous run, paused at the saved song
  /// and position. Songs deleted since then are skipped.
  Future<void> restore() async {
    final store = _queueStore;
    final saved = await store?.load();
    if (store == null || saved == null || _songs.isNotEmpty) return;
    final plan = planRestore(
      saved,
      await store.songsByIds([...saved.songIds, ...?saved.originalSongIds]),
    );
    if (plan == null) return;

    _queue = QueueModel.restored(plan.original, plan.order);
    _songs = _queue.songs;
    _source = saved.source;
    _sourceLabel = saved.sourceLabel;
    _repeat = saved.repeat;
    _publishQueue();
    await _player.setLoopMode(_loopModeFor(_repeat));
    await _player.setAudioSources(
      _sourcesFor(_songs),
      initialIndex: plan.index,
      initialPosition: plan.position,
    );
    _lastSavedPosition = plan.position;
    _publishStatus();
  }

  // audio_service callbacks -------------------------------------------------

  @override
  Future<void> play() async {
    if (_songs.isEmpty) return;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    unawaited(_savePosition());
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    unawaited(_savePosition());
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > _restartThreshold || !_player.hasPrevious) {
      _recorder.trackRestarted();
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _songs.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffle(shuffleMode != AudioServiceShuffleMode.none);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      setRepeat(switch (repeatMode) {
        AudioServiceRepeatMode.none => RepeatSetting.off,
        AudioServiceRepeatMode.one => RepeatSetting.one,
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => RepeatSetting.all,
      });

  @override
  Future<void> stop() async {
    await _savePosition();
    await _player.stop();
    await _recorder.flush();
    await super.stop();
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _recorder.flush();
    await _player.dispose();
    await _status.close();
  }

  // State ---------------------------------------------------------------------

  QueueSong? get _currentSong {
    final index = _player.currentIndex;
    return index == null || index >= _songs.length ? null : _songs[index];
  }

  void _onIndex(int? index) {
    if (_rebuilding) return;
    final song = _currentSong;
    _recorder.trackChanged(song, source: _source);
    _publishStatus();
    unawaited(_savePosition());
    if (song == null) return;
    final item = _mediaItemFor(song);
    mediaItem.add(item);
    unawaited(_attachArtwork(song, item));
  }

  void _onDiscontinuity(PositionDiscontinuity discontinuity) {
    // Repeat-one (or a one-song repeat-all) loops without changing index:
    // that is a new listen.
    if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance &&
        discontinuity.previousEvent.currentIndex ==
            discontinuity.event.currentIndex) {
      _recorder.trackRestarted();
    }
  }

  void _onPosition(Duration position) {
    _recorder.positionChanged(position);
    if (_player.playing &&
        (position - _lastSavedPosition).abs() >= _savePositionEvery) {
      unawaited(_savePosition());
    }
  }

  Future<void> _attachArtwork(QueueSong song, MediaItem item) async {
    final file = await _artwork.fileFor(
      ArtworkRequest(
        songId: song.id,
        albumId: song.albumId,
        sizePx: _artSize,
        version: song.version,
      ),
    );
    // Only if the song is still current.
    if (file == null || _currentSong != song) return;
    mediaItem.add(item.copyWith(artUri: file.uri));
  }

  Future<void> _onPlayerState(PlayerState state) async {
    final ready = state.processingState == ProcessingState.ready;
    _recorder.activeChanged(state.playing && ready);
    _publishStatus();
    if (state.processingState == ProcessingState.completed) {
      // End of the queue (repeat off): back to the start, paused.
      _recorder.trackEnded();
      await _player.pause();
      await _player.seek(Duration.zero, index: 0);
    }
  }

  void _publishQueue() => queue.add([for (final s in _songs) _mediaItemFor(s)]);

  void _publishStatus() {
    final processing = _player.processingState;
    _lastStatus = PlaybackStatus(
      song: _currentSong,
      playing: _player.playing && processing != ProcessingState.completed,
      buffering:
          processing == ProcessingState.loading ||
          processing == ProcessingState.buffering,
      duration: _player.duration ?? _currentSong?.duration ?? Duration.zero,
      shuffle: _shuffled,
      repeat: _repeat,
      source: _source,
      sourceLabel: _sourceLabel,
      queue: _songs,
      queueIndex: _player.currentIndex ?? 0,
    );
    if (!_status.isClosed) _status.add(_lastStatus);
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
        shuffleMode: _shuffled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (_repeat) {
          RepeatSetting.off => AudioServiceRepeatMode.none,
          RepeatSetting.all => AudioServiceRepeatMode.all,
          RepeatSetting.one => AudioServiceRepeatMode.one,
        },
      ),
    );
  }

  // Persistence --------------------------------------------------------------

  Future<void> _saveQueue() async {
    final store = _queueStore;
    if (store == null || _songs.isEmpty) return;
    _lastSavedPosition = _player.position;
    await store.save(
      SavedQueue(
        songIds: [for (final s in _songs) s.id],
        originalSongIds: _shuffled
            ? [for (final s in _queue.original) s.id]
            : null,
        currentIndex: _player.currentIndex ?? 0,
        position: _player.position,
        shuffle: _shuffled,
        repeat: _repeat,
        source: _source,
        sourceLabel: _sourceLabel,
      ),
      at: DateTime.now(),
    );
  }

  Future<void> _savePosition() async {
    final store = _queueStore;
    final index = _player.currentIndex;
    if (store == null || index == null || _songs.isEmpty) return;
    _lastSavedPosition = _player.position;
    await store.savePosition(index, _player.position, at: DateTime.now());
  }

  static LoopMode _loopModeFor(RepeatSetting mode) => switch (mode) {
    RepeatSetting.off => LoopMode.off,
    RepeatSetting.all => LoopMode.all,
    RepeatSetting.one => LoopMode.one,
  };

  static List<AudioSource> _sourcesFor(List<QueueSong> songs) => [
    for (final s in songs) AudioSource.uri(s.uri),
  ];

  static MediaItem _mediaItemFor(QueueSong song) => MediaItem(
    id: song.uri.toString(),
    title: song.title,
    artist: song.displayArtist,
    album: song.displayAlbum,
    duration: song.duration,
    extras: {'songId': song.id},
  );
}
