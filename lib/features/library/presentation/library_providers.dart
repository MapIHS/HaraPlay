import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/library_dao.dart';
import '../../settings/presentation/min_song_length_controller.dart';
import '../data/library_sync_service.dart';

/// Live song / album / folder counts under the current minimum length.
final libraryCountsProvider = StreamProvider<LibraryCounts>(
  (ref) => ref
      .watch(libraryDaoProvider)
      .watchCounts(
        minDurationMs: ref.watch(minSongLengthProvider).inMilliseconds,
      ),
);

/// The state of the last user-visible library sync.
class LibrarySyncController extends Notifier<AsyncValue<SyncResult?>> {
  @override
  AsyncValue<SyncResult?> build() => const AsyncData(null);

  /// Syncs with MediaStore. Errors are kept in [state] and rethrown.
  Future<SyncResult> sync() async {
    state = const AsyncLoading<SyncResult?>();
    try {
      final result = await ref.read(librarySyncServiceProvider).sync();
      state = AsyncData(result);
      return result;
    } catch (error, stack) {
      state = AsyncError<SyncResult?>(error, stack);
      rethrow;
    }
  }
}

final librarySyncControllerProvider =
    NotifierProvider<LibrarySyncController, AsyncValue<SyncResult?>>(
      LibrarySyncController.new,
    );
