import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/features.dart';
import '../../equalizer/data/audio_effects.dart';
import '../../equalizer/domain/equalizer.dart';
import '../../equalizer/presentation/equalizer_controller.dart';

/// The audio effects of the main player and the crossfade's tail player,
/// set up once at startup.
class PlayerAudio {
  const PlayerAudio._({
    required this.info,
    required this.sink,
    required this.mainEffects,
    required this._tailEffects,
  });

  /// No effects at all: nothing probed, created or attached.
  static final none = PlayerAudio._(
    info: AudioEffectsInfo.none,
    sink: const NoAudioEffects(),
    mainEffects: const [],
    tailEffects: () => const [],
  );

  final AudioEffectsInfo info;
  final AudioEffectsSink sink;

  /// Effects for the main player's pipeline.
  final List<AndroidAudioEffect> mainEffects;

  final List<AndroidAudioEffect> Function() _tailEffects;

  /// Effects for a new tail player (an effect belongs to one player's
  /// audio session).
  List<AndroidAudioEffect> tailEffects() => _tailEffects();

  /// The main player; without effects exactly the plain player HaraPlay
  /// had before the equalizer.
  AudioPlayer mainPlayer() => mainEffects.isEmpty
      ? AudioPlayer()
      : AudioPlayer(
          audioPipeline: AudioPipeline(androidAudioEffects: mainEffects),
        );
}

/// Sets up the players' effects, or [PlayerAudio.none] while the
/// equalizer is disabled ([kEqualizerEnabled]); saved settings are then
/// left unread.
Future<PlayerAudio> setUpPlayerAudio(
  SharedPreferencesWithCache preferences, {
  bool enabled = kEqualizerEnabled,
  Future<AudioEffectsInfo> Function() probe = probeAudioEffects,
  AndroidEqualizer Function() newEqualizer = AndroidEqualizer.new,
  AndroidLoudnessEnhancer Function() newLoudness = AndroidLoudnessEnhancer.new,
}) async {
  if (!enabled) return PlayerAudio.none;

  // As in 0.1.0. Only effects the device has: just_audio creating a
  // missing one would break playback.
  final effectsInfo = await probe();
  final equalizer = effectsInfo.equalizer == null ? null : newEqualizer();
  final loudness = effectsInfo.loudness ? newLoudness() : null;
  // The crossfade's tail player gets its own copies of the effects; the
  // group keeps their settings in step.
  final effects = AudioEffectsGroup([
    JustAudioEffects(equalizer: equalizer, loudness: loudness),
  ]);
  await applyEqualizerSettings(
    loadEqualizerSettings(preferences),
    effectsInfo,
    effects,
  );
  return PlayerAudio._(
    info: effectsInfo,
    sink: effects,
    mainEffects: [?equalizer, ?loudness],
    tailEffects: () {
      final eq = effectsInfo.equalizer == null ? null : newEqualizer();
      final boost = effectsInfo.loudness ? newLoudness() : null;
      unawaited(effects.add(JustAudioEffects(equalizer: eq, loudness: boost)));
      return [?eq, ?boost];
    },
  );
}
