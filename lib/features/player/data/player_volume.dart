import 'dart:async';

import '../../audio_info/data/audio_info_repository.dart';
import '../../audio_info/domain/audio_info.dart';

/// The player's own volume: the sleep timer's fade times the current
/// song's ReplayGain. The system volume is never touched.
///
/// Each song's gain is read ahead (the next song's while the current one
/// plays), so a gapless change to a song with a different gain can apply
/// it right away.
class PlayerVolume {
  PlayerVolume({required this.setVolume, this.source});

  final Future<void> Function(double volume) setVolume;

  /// Null: no ReplayGain (tests without files).
  final AudioInfoSource? source;

  ReplayGainMode _mode = ReplayGainMode.off;
  double _fade = 1;
  AudioInfoKey? _current;

  /// The current song's gain factor; kept from the previous song until the
  /// new one's is known, so a quiet run doesn't blast while it loads.
  double _gain = 1;
  double? _applied;
  final _known = <AudioInfoKey, ReplayGain>{};

  ReplayGainMode get mode => _mode;

  /// The crossfade's ramp on the main player (1 = none).
  double _ramp = 1;

  /// The volume sent to the player.
  double get volume => _fade * _gain * _ramp;

  /// The volume without the crossfade ramp: what the outgoing song's tail
  /// plays at on the crossfade's second player.
  double get unramped => _fade * _gain;

  Future<void> setMode(ReplayGainMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    if (_current case final song?) await _resolve(song);
    await _apply();
  }

  /// From the sleep timer (1 = no fade).
  Future<void> setFade(double fade) {
    _fade = fade.clamp(0.0, 1.0);
    return _apply();
  }

  /// From the crossfader.
  Future<void> setRamp(double ramp) {
    _ramp = ramp.clamp(0.0, 1.0);
    return _apply();
  }

  /// A new song became current; [next] is the one expected after it.
  Future<void> songChanged(AudioInfoKey? song, {AudioInfoKey? next}) async {
    _current = song;
    if (next != null) unawaited(_lookUp(next));
    if (song != null) await _resolve(song);
    await _apply();
  }

  /// The upcoming song changed (queue edits), so read its gain early.
  void upcoming(AudioInfoKey? next) {
    if (next != null) unawaited(_lookUp(next));
  }

  /// Sets [_gain] for [song], reading its tags if needed.
  Future<void> _resolve(AudioInfoKey song) async {
    if (_mode == ReplayGainMode.off) {
      _gain = 1;
      return;
    }
    final known = _known[song];
    if (known != null) {
      _gain = replayGainVolume(known, _mode);
      return;
    }
    // Apply the fade at the old gain now; the new gain follows.
    await _apply();
    final gain = await _lookUp(song);
    if (_current == song) _gain = replayGainVolume(gain, _mode);
  }

  Future<ReplayGain> _lookUp(AudioInfoKey song) async {
    final known = _known[song];
    if (known != null) return known;
    final source = this.source;
    if (source == null) return ReplayGain.none;
    final gain = (await source.infoFor(song)).replayGain;
    _known[song] = gain;
    if (_known.length > 64) _known.remove(_known.keys.first);
    return gain;
  }

  Future<void> _apply() async {
    final target = volume;
    if (target == _applied) return;
    _applied = target;
    await setVolume(target);
  }
}
