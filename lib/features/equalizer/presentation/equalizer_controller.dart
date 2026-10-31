import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../data/audio_effects.dart';
import '../domain/equalizer.dart';

/// Which effects the device has; probed in `bootstrap.dart`.
final audioEffectsInfoProvider = Provider<AudioEffectsInfo>(
  (ref) => AudioEffectsInfo.none,
);

/// Where settings are applied; the player's effects in `bootstrap.dart`.
final audioEffectsSinkProvider = Provider<AudioEffectsSink>(
  (ref) => const NoAudioEffects(),
);

const _prefsKey = 'audio.equalizer';

/// Reads the saved settings (also used at startup, before any UI).
EqualizerSettings loadEqualizerSettings(SharedPreferencesWithCache prefs) =>
    EqualizerSettings.decode(prefs.getString(_prefsKey));

/// Sends [settings] to [sink] for the device described by [info].
Future<void> applyEqualizerSettings(
  EqualizerSettings settings,
  AudioEffectsInfo info,
  AudioEffectsSink sink,
) {
  final layout = info.equalizer;
  return sink.apply(
    equalizerEnabled: settings.enabled && layout != null,
    gains: layout == null ? const [] : settings.gainsFor(layout),
    loudnessDb: info.loudness ? settings.loudnessDb : 0,
  );
}

class EqualizerController extends Notifier<EqualizerSettings> {
  @override
  EqualizerSettings build() =>
      loadEqualizerSettings(ref.watch(sharedPreferencesProvider));

  void setEnabled(bool enabled) => _update(state.copyWith(enabled: enabled));

  /// Choosing a preset also switches the equalizer on.
  void selectPreset(String id) =>
      _update(state.copyWith(presetId: id, enabled: true));

  /// Moves one band; the current curve becomes the custom one.
  void setBandGain(int index, double gain) {
    final layout = ref.read(audioEffectsInfoProvider).equalizer;
    if (layout == null || index < 0 || index >= layout.bands.length) return;
    final gains = state.gainsFor(layout)..[index] = layout.clamp(gain);
    _update(
      state.copyWith(
        presetId: customPresetId,
        enabled: true,
        customGains: {
          ...state.customGains,
          for (var i = 0; i < gains.length; i++)
            layout.bands[i].round(): gains[i],
        },
      ),
    );
  }

  void setLoudness(double db) => _update(
    state.copyWith(
      loudnessDb: db.clamp(0, EqualizerSettings.maxLoudnessDb).toDouble(),
    ),
  );

  /// Flat bands and no loudness boost; the custom curve is kept.
  void reset() => _update(state.copyWith(presetId: 'flat', loudnessDb: 0));

  void _update(EqualizerSettings settings) {
    state = settings;
    ref.read(sharedPreferencesProvider).setString(_prefsKey, settings.encode());
    applyEqualizerSettings(
      settings,
      ref.read(audioEffectsInfoProvider),
      ref.read(audioEffectsSinkProvider),
    );
  }
}

final equalizerProvider =
    NotifierProvider<EqualizerController, EqualizerSettings>(
      EqualizerController.new,
    );
