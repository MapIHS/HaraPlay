import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import 'player_providers.dart';

const stopOnTaskRemovedKey = 'playback.stopOnTaskRemoved';

/// The saved choice (also applied at startup). Off by default.
bool loadStopOnTaskRemoved(SharedPreferencesWithCache prefs) =>
    prefs.getBool(stopOnTaskRemovedKey) ?? false;

/// "Stop when removed from Recent apps": with it on, swiping HaraPlay away
/// from Recent apps stops playback. While paused it always stops.
class StopOnTaskRemovedController extends Notifier<bool> {
  @override
  bool build() => loadStopOnTaskRemoved(ref.watch(sharedPreferencesProvider));

  Future<void> set(bool stop) async {
    if (stop == state) return;
    state = stop;
    ref.read(playerProvider).setStopOnTaskRemoved(stop);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(stopOnTaskRemovedKey, stop);
  }
}

final stopOnTaskRemovedProvider =
    NotifierProvider<StopOnTaskRemovedController, bool>(
      StopOnTaskRemovedController.new,
    );
