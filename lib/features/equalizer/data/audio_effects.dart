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
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
  });
}

/// Does nothing: for devices without effects, and tests.
class NoAudioEffects implements AudioEffectsSink {
  const NoAudioEffects();

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
  }) async {}
}

/// just_audio's Android effects. Band gains can only be set once the
/// player has loaded something (that's when the platform creates the
/// equalizer), so they are applied as soon as it has; just_audio restores
/// them whenever it recreates the effect.
class JustAudioEffects implements AudioEffectsSink {
  JustAudioEffects({this.equalizer, this.loudness});

  final AndroidEqualizer? equalizer;
  final AndroidLoudnessEnhancer? loudness;

  /// The latest gains; an older pending application skips itself.
  List<double> _gains = const [];

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
  }) async {
    try {
      final eq = equalizer;
      if (eq != null) {
        await eq.setEnabled(equalizerEnabled);
        _gains = gains;
        unawaited(_applyGains(eq, gains));
      }
      final enhancer = loudness;
      if (enhancer != null) {
        await enhancer.setTargetGain(loudnessDb);
        await enhancer.setEnabled(loudnessDb > 0);
      }
    } on PlatformException catch (e) {
      // E.g. another app took control of the effect; keep playing.
      debugPrint('HaraPlay audio effects: $e');
    }
  }

  Future<void> _applyGains(AndroidEqualizer eq, List<double> gains) async {
    final parameters = await eq.parameters;
    if (!identical(gains, _gains)) return;
    try {
      for (final band in parameters.bands) {
        if (band.index < gains.length) await band.setGain(gains[band.index]);
      }
    } on PlatformException catch (e) {
      debugPrint('HaraPlay equalizer bands: $e');
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
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
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
        ),
    ]);
  }
}
