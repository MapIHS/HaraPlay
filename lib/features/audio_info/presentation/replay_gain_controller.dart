import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/audio_info.dart';

const _prefsKey = 'audio.replayGain';

/// The saved mode (also read at startup, before any UI). Off by default.
ReplayGainMode loadReplayGainMode(SharedPreferencesWithCache prefs) {
  final stored = prefs.getString(_prefsKey);
  return ReplayGainMode.values.firstWhere(
    (m) => m.name == stored,
    orElse: () => ReplayGainMode.off,
  );
}

class ReplayGainController extends Notifier<ReplayGainMode> {
  @override
  ReplayGainMode build() =>
      loadReplayGainMode(ref.watch(sharedPreferencesProvider));

  Future<void> set(ReplayGainMode mode) async {
    if (mode == state) return;
    state = mode;
    ref.read(playerProvider).setReplayGainMode(mode);
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, mode.name);
  }
}

final replayGainProvider =
    NotifierProvider<ReplayGainController, ReplayGainMode>(
      ReplayGainController.new,
    );

/// Settings subtitle and the sheet's descriptions.
String replayGainDescription(ReplayGainMode mode) => switch (mode) {
  ReplayGainMode.off => 'Songs play at the volume they were mastered at',
  ReplayGainMode.track => 'Every song at the same loudness; best for shuffle',
  ReplayGainMode.album =>
    'Albums at the same loudness, keeping quiet and loud songs as intended',
};
