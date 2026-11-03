import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/equalizer.dart';

/// Asks the platform which effects exist (see `AudioEffectsProbe.kt`).
///
/// Waits at most [timeout]: startup must not hang on a slow audio server
/// (seen right after boot). Without an answer this launch plays without
/// effects, which is safe; they come back on the next launch.
Future<AudioEffectsInfo> probeAudioEffects({
  Duration timeout = const Duration(milliseconds: 1500),
}) async {
  try {
    final map = await const MethodChannel('haraplay/playback')
        .invokeMapMethod<Object?, Object?>('audioEffects')
        .timeout(timeout);
    return AudioEffectsInfo.fromChannel(map);
  } on TimeoutException {
    debugPrint('HaraPlay audio effects: probe timed out');
    return AudioEffectsInfo.none;
  } on PlatformException {
    return AudioEffectsInfo.none;
  } on MissingPluginException {
    return AudioEffectsInfo.none;
  }
}

/// Where equalizer settings end up: the player's audio effects.
abstract interface class AudioEffectsSink {
  /// [smooth]: a discrete change (switching on or off, a preset); the
  /// player's volume dips around it when guarded (see
  /// `EffectsChangeGuard`). Dragging a band passes false.
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
    bool smooth = true,
  });

  /// Whether applying these settings would switch on an effect that isn't
  /// on yet. Some devices re-route the audio when an effect is switched on
  /// or off mid-playback, with a loud glitch; this is when that can happen.
  bool switchesOn({required bool equalizerEnabled, required double loudnessDb});
}

/// Does nothing: for devices without effects, and tests.
class NoAudioEffects implements AudioEffectsSink {
  const NoAudioEffects();

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
    bool smooth = true,
  }) async {}

  @override
  bool switchesOn({
    required bool equalizerEnabled,
    required double loudnessDb,
  }) => false;
}

/// The parts of Android's Equalizer that [JustAudioEffects] uses.
abstract interface class EqualizerControl {
  Future<void> setEnabled(bool enabled);

  /// Sets every band; a newer call supersedes one still waiting.
  Future<void> setGains(List<double> gains);

  /// The platform effect exists (the player has loaded something), so
  /// [setGains] completes promptly.
  bool get ready;
}

/// The parts of Android's LoudnessEnhancer that [JustAudioEffects] uses.
abstract interface class LoudnessControl {
  Future<void> setEnabled(bool enabled);
  Future<void> setTargetGain(double db);
}

/// The player's Android effects.
///
/// An effect is **never switched off** once it has been switched on:
/// "off" becomes a flat curve (all bands 0 dB, loudness 0 dB) with the
/// effect still running. Switching an effect on or off mid-playback
/// rebuilds the audio path, and some devices (seen on a vivo phone) let a
/// loud burst through at that moment, even at volume 0. An effect that was
/// never used is never switched on, so "Off" stays untouched for anyone
/// who never uses the equalizer.
class JustAudioEffects implements AudioEffectsSink {
  JustAudioEffects({this.equalizer, this.loudness});

  /// just_audio's effects, wrapped.
  factory JustAudioEffects.of({
    AndroidEqualizer? equalizer,
    AndroidLoudnessEnhancer? loudness,
  }) => JustAudioEffects(
    equalizer: equalizer == null ? null : _JustAudioEqualizer(equalizer),
    loudness: loudness == null ? null : _JustAudioLoudness(loudness),
  );

  final EqualizerControl? equalizer;
  final LoudnessControl? loudness;

  bool _equalizerOn = false;
  bool _loudnessOn = false;

  @override
  bool switchesOn({
    required bool equalizerEnabled,
    required double loudnessDb,
  }) =>
      (equalizer != null && equalizerEnabled && !_equalizerOn) ||
      (loudness != null && loudnessDb > 0 && !_loudnessOn);

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
    bool smooth = true,
  }) async {
    try {
      final eq = equalizer;
      if (eq != null && (equalizerEnabled || _equalizerOn)) {
        final curve = equalizerEnabled
            ? gains
            : List<double>.filled(gains.length, 0);
        // Gains first, then switch on: it starts with the right curve.
        final pending = eq.setGains(curve);
        // Before the player has loaded anything the bands don't exist yet
        // (startup); just_audio applies them once they do.
        if (eq.ready) {
          await pending;
        } else {
          unawaited(pending);
        }
        if (!_equalizerOn) {
          await eq.setEnabled(true);
          _equalizerOn = true;
        }
      }
      final boost = loudness;
      if (boost != null && (loudnessDb > 0 || _loudnessOn)) {
        await boost.setTargetGain(loudnessDb);
        if (!_loudnessOn) {
          await boost.setEnabled(true);
          _loudnessOn = true;
        }
      }
    } on PlatformException catch (e) {
      // E.g. another app took control of the effect; keep playing.
      debugPrint('HaraPlay audio effects: $e');
    }
  }
}

class _JustAudioEqualizer implements EqualizerControl {
  _JustAudioEqualizer(this._eq);

  final AndroidEqualizer _eq;
  List<double> _latest = const [];
  bool _ready = false;

  @override
  bool get ready => _ready;

  @override
  Future<void> setEnabled(bool enabled) => _eq.setEnabled(enabled);

  @override
  Future<void> setGains(List<double> gains) async {
    _latest = gains;
    final parameters = await _eq.parameters;
    _ready = true;
    if (!identical(gains, _latest)) return;
    try {
      for (final band in parameters.bands) {
        if (band.index < gains.length) await band.setGain(gains[band.index]);
      }
    } on PlatformException catch (e) {
      debugPrint('HaraPlay equalizer bands: $e');
    }
  }
}

class _JustAudioLoudness implements LoudnessControl {
  _JustAudioLoudness(this._effect);

  final AndroidLoudnessEnhancer _effect;

  @override
  Future<void> setEnabled(bool enabled) => _effect.setEnabled(enabled);

  @override
  Future<void> setTargetGain(double db) => _effect.setTargetGain(db);
}

/// Runs effect changes through the player's [EffectsChangeGuard]: the
/// player's own volume dips around a discrete change, and playback pauses
/// briefly while an effect is switched on.
class GuardedAudioEffects implements AudioEffectsSink {
  GuardedAudioEffects(this._inner, this._guard);

  final AudioEffectsSink _inner;
  final EffectsChangeGuard _guard;

  @override
  bool switchesOn({
    required bool equalizerEnabled,
    required double loudnessDb,
  }) => _inner.switchesOn(
    equalizerEnabled: equalizerEnabled,
    loudnessDb: loudnessDb,
  );

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
    bool smooth = true,
  }) => _guard.run(
    () => _inner.apply(
      equalizerEnabled: equalizerEnabled,
      gains: gains,
      loudnessDb: loudnessDb,
      smooth: smooth,
    ),
    switchesOn: switchesOn(
      equalizerEnabled: equalizerEnabled,
      loudnessDb: loudnessDb,
    ),
    smooth: smooth,
  );
}

/// Makes effect changes safe to hear: with music playing, the player's own
/// volume ramps down to silence, the change happens, and it ramps back up
/// to where it was (never higher). Switching an effect on (when the audio
/// path may be rebuilt) also pauses playback for a moment, so nothing is
/// playing if the device glitches. Changes run one at a time.
class EffectsChangeGuard {
  EffectsChangeGuard({
    required this._isPlaying,
    required this._setDuck,
    required this._pause,
    required this._play,
    Future<void> Function()? beforeChange,
    Future<void> Function(Duration)? wait,
    this.rampDown = const Duration(milliseconds: 60),
    this.quiet = const Duration(milliseconds: 50),
    this.rampUp = const Duration(milliseconds: 150),
    this.settle = const Duration(milliseconds: 80),
    this.pausedSettle = const Duration(milliseconds: 250),
  }) : _beforeChange = beforeChange ?? (() async {}),
       _wait = wait ?? Future<void>.delayed;

  final bool Function() _isPlaying;
  final Future<void> Function(double factor) _setDuck;
  final Future<void> Function() _pause;
  final Future<void> Function() _play;
  final Future<void> Function() _beforeChange;
  final Future<void> Function(Duration) _wait;

  final Duration rampDown;
  final Duration rampUp;

  /// Kept silent after the ramp-down, before the change: a volume change
  /// reaches the device's mixer a mix period or two later (measured on
  /// the emulator: without this the change landed at 10–20 % volume).
  final Duration quiet;

  /// Silence kept after a change before ramping back up.
  final Duration settle;

  /// The pause around switching an effect on.
  final Duration pausedSettle;

  static const _step = Duration(milliseconds: 10);

  Future<void> _queue = Future.value();

  Future<void> run(
    Future<void> Function() change, {
    required bool switchesOn,
    bool smooth = true,
  }) {
    final task = _queue.then(
      (_) => _run(change, switchesOn: switchesOn, smooth: smooth),
    );
    _queue = task.catchError((Object _) {});
    return task;
  }

  Future<void> _run(
    Future<void> Function() change, {
    required bool switchesOn,
    required bool smooth,
  }) async {
    if (!_isPlaying() || (!smooth && !switchesOn)) return change();
    await _beforeChange();
    await _ramp(1, 0, rampDown);
    await _wait(quiet);
    try {
      if (switchesOn) {
        await _pause();
        try {
          await change();
          await _wait(pausedSettle);
        } finally {
          await _play();
        }
      } else {
        await change();
        await _wait(settle);
      }
    } finally {
      await _ramp(0, 1, rampUp);
    }
  }

  Future<void> _ramp(double from, double to, Duration length) async {
    final steps = (length.inMilliseconds / _step.inMilliseconds).ceil();
    for (var i = 1; i <= steps; i++) {
      await _setDuck(from + (to - from) * i / steps);
      if (i < steps) await _wait(_step);
    }
  }
}

/// Applies the same settings to several players' effects (the main player
/// and the crossfade's tail player). A sink added later gets the latest
/// settings straight away.
class AudioEffectsGroup implements AudioEffectsSink {
  AudioEffectsGroup(List<AudioEffectsSink> sinks) : _sinks = [...sinks];

  final List<AudioEffectsSink> _sinks;
  ({bool equalizerEnabled, List<double> gains, double loudnessDb})? _latest;

  Future<void> add(AudioEffectsSink sink) async {
    _sinks.add(sink);
    final latest = _latest;
    if (latest != null) {
      await sink.apply(
        equalizerEnabled: latest.equalizerEnabled,
        gains: latest.gains,
        loudnessDb: latest.loudnessDb,
      );
    }
  }

  @override
  bool switchesOn({
    required bool equalizerEnabled,
    required double loudnessDb,
  }) => _sinks.any(
    (sink) => sink.switchesOn(
      equalizerEnabled: equalizerEnabled,
      loudnessDb: loudnessDb,
    ),
  );

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
    bool smooth = true,
  }) async {
    _latest = (
      equalizerEnabled: equalizerEnabled,
      gains: gains,
      loudnessDb: loudnessDb,
    );
    await Future.wait([
      for (final sink in [..._sinks])
        sink.apply(
          equalizerEnabled: equalizerEnabled,
          gains: gains,
          loudnessDb: loudnessDb,
          smooth: smooth,
        ),
    ]);
  }
}
