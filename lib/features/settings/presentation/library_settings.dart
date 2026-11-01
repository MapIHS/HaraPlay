import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../library/domain/excluded_folders.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/rescan.dart';
import '../data/settings_repository.dart';
import 'choice_sheet.dart';
import 'excluded_folders_controller.dart';
import 'min_song_length_controller.dart';
import 'settings_tile.dart';

/// Settings → Library: rescan, excluded folders and the minimum song
/// length.
class LibrarySettings extends ConsumerWidget {
  const LibrarySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(librarySyncControllerProvider).isLoading;
    final minLength = ref.watch(minSongLengthProvider);
    final excluded = ref.watch(excludedFoldersProvider);
    return Column(
      children: [
        SettingsTile(
          icon: HaraIcons.refreshCw,
          title: syncing ? 'Scanning…' : 'Rescan library',
          subtitle: 'Look for music added or removed on this phone',
          onTap: syncing ? null : () => rescanWithFeedback(context, ref),
        ),
        SettingsTile(
          icon: HaraIcons.folder,
          title: 'Excluded folders',
          subtitle: switch (excluded.length) {
            0 => 'None: music from every folder is shown',
            1 => displayFolder(excluded.single),
            final n => '$n folders',
          },
          onTap: () => context.push(AppRoutes.excludedFolders),
        ),
        SettingsTile(
          icon: HaraIcons.timer,
          title: 'Hide short audio',
          subtitle: minLength == Duration.zero
              ? 'Off: every audio file is shown'
              : 'Hides files shorter than ${minLength.inSeconds} s',
          onTap: () => showHaraSheet<void>(
            context: context,
            title: 'Hide short audio',
            builder: (_) => const _MinLengthSheet(),
          ),
        ),
      ],
    );
  }
}

class _MinLengthSheet extends ConsumerWidget {
  const _MinLengthSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ChoiceSheet<Duration>(
    intro:
        'Ringtones, voice notes and other short clips stay on your '
        'phone, they are just left out of the library.',
    options: SettingsRepository.minSongLengthOptions,
    selected: ref.watch(minSongLengthProvider),
    label: (option) => option == Duration.zero
        ? 'Off'
        : 'Shorter than ${option.inSeconds} seconds',
    onSelected: ref.read(minSongLengthProvider.notifier).set,
  );
}
