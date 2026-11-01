import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/crossfade_settings.dart';
import 'player_providers.dart';

const _lengthKey = 'playback.crossfadeSeconds';
const _onSkipKey = 'playback.crossfadeOnSkip';

/// Choices in Settings; 0 is off (the default).
const crossfadeChoices = [0, 2, 4, 6, 8, 10, 12];

/// The saved settings (also applied at startup). Off by default.
CrossfadeSettings loadCrossfade(SharedPreferencesWithCache prefs) {
  final seconds = prefs.getInt(_lengthKey) ?? 0;
  return (
    length: Duration(seconds: crossfadeChoices.contains(seconds) ? seconds : 0),
    onSkip: prefs.getBool(_onSkipKey) ?? false,
  );
}

class CrossfadeController extends Notifier<CrossfadeSettings> {
  @override
  CrossfadeSettings build() =>
      loadCrossfade(ref.watch(sharedPreferencesProvider));

  Future<void> setLength(int seconds) =>
      _set((length: Duration(seconds: seconds), onSkip: state.onSkip));

  Future<void> setOnSkip(bool onSkip) =>
      _set((length: state.length, onSkip: onSkip));

  Future<void> _set(CrossfadeSettings settings) async {
    if (settings == state) return;
    state = settings;
    ref.read(playerProvider).setCrossfade(settings);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_lengthKey, settings.length.inSeconds);
    await prefs.setBool(_onSkipKey, settings.onSkip);
  }
}

final crossfadeProvider =
    NotifierProvider<CrossfadeController, CrossfadeSettings>(
      CrossfadeController.new,
    );

/// "Off" or "6 s".
String crossfadeLabel(int seconds) => seconds == 0 ? 'Off' : '$seconds s';
