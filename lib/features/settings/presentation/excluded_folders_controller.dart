import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/data/library_sync_service.dart';
import '../../library/domain/excluded_folders.dart';
import '../data/settings_repository.dart';

/// Folders whose songs are hidden from the library (subfolders included).
/// Changes apply at once, without a rescan.
class ExcludedFoldersController extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.watch(settingsRepositoryProvider).readExcludedFolders();

  Future<void> add(String folder) => _set(addExcludedFolder(state, folder));

  Future<void> remove(String folder) => _set([
    for (final f in state)
      if (f != folder) f,
  ]);

  Future<void> _set(List<String> folders) async {
    state = folders;
    await ref.read(settingsRepositoryProvider).writeExcludedFolders(folders);
    await ref.read(libraryDaoProvider).applyExclusions(folders);
  }
}

final excludedFoldersProvider =
    NotifierProvider<ExcludedFoldersController, List<String>>(
      ExcludedFoldersController.new,
    );
