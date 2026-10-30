import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

/// Songs shorter than this are left out of the library, search and counts.
/// They stay in the database, so changing it never loses favorites.
class MinSongLengthController extends Notifier<Duration> {
  @override
  Duration build() => ref.watch(settingsRepositoryProvider).readMinSongLength();

  Future<void> set(Duration length) async {
    if (length == state) return;
    state = length;
    await ref.read(settingsRepositoryProvider).writeMinSongLength(length);
  }
}

final minSongLengthProvider =
    NotifierProvider<MinSongLengthController, Duration>(
      MinSongLengthController.new,
    );
