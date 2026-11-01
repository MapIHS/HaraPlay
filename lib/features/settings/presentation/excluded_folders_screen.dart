import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../library/data/library_sync_service.dart';
import '../../library/domain/excluded_folders.dart';
import 'excluded_folders_controller.dart';

/// Settings › Library › Excluded folders: folders whose songs are left out
/// of the library, and a picker to add more.
class ExcludedFoldersScreen extends ConsumerWidget {
  const ExcludedFoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excluded = ref.watch(excludedFoldersProvider);
    final textTheme = Theme.of(context).textTheme;
    final colors = HaraColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Excluded folders')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              HaraSpacing.sm,
              HaraSpacing.gutter,
              HaraSpacing.lg,
            ),
            child: Text(
              'Songs in these folders and their subfolders are left out of '
              'Library, Home and Search. They stay in Liked songs and your '
              'playlists, and nothing is deleted.',
              style: textTheme.bodyMedium!.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ),
          if (excluded.isEmpty)
            // EmptyState fills its height, so give it one inside the list.
            const SizedBox(
              height: 260,
              child: EmptyState(
                icon: HaraIcons.folder,
                title: 'No excluded folders',
                message: 'Every folder with music is in your library.',
              ),
            )
          else
            for (final folder in excluded)
              ListTile(
                leading: const Icon(HaraIcons.folder),
                title: Text(displayFolder(folder)),
                trailing: HaraIconButton(
                  icon: HaraIcons.x,
                  tooltip: 'Include ${displayFolder(folder)} again',
                  onPressed: () =>
                      ref.read(excludedFoldersProvider.notifier).remove(folder),
                ),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              HaraSpacing.lg,
              HaraSpacing.gutter,
              0,
            ),
            child: HaraButton(
              label: 'Add folder',
              icon: HaraIcons.plus,
              variant: HaraButtonVariant.secondary,
              expand: true,
              onPressed: () => _pickFolder(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final songsByFolder = await ref.read(libraryDaoProvider).songFolders();
    if (!context.mounted) return;
    final choices = folderChoices(
      songsByFolder,
      ref.read(excludedFoldersProvider),
    );
    final picked = await showHaraSheet<String>(
      context: context,
      title: 'Exclude a folder',
      builder: (context) => _FolderPicker(choices: choices),
    );
    if (picked != null) {
      await ref.read(excludedFoldersProvider.notifier).add(picked);
    }
  }
}

class _FolderPicker extends StatelessWidget {
  const _FolderPicker({required this.choices});

  final List<FolderChoice> choices;

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(HaraSpacing.xl),
        child: Text('No other folders with music.'),
      );
    }
    final colors = HaraColors.of(context);
    // Indent subfolders under the shallowest folder shown.
    int depth(String path) => '/'.allMatches(path).length;
    final base = choices
        .map((c) => depth(c.path))
        .reduce((a, b) => a < b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final choice in choices)
          ListTile(
            contentPadding: EdgeInsets.only(
              left:
                  HaraSpacing.gutter +
                  HaraSpacing.lg * (depth(choice.path) - base).clamp(0, 6),
              right: HaraSpacing.gutter,
            ),
            leading: const Icon(HaraIcons.folder),
            title: Text(
              // Subfolders show their own name; the indent shows the parent.
              depth(choice.path) == base
                  ? displayFolder(choice.path)
                  : choice.path.substring(choice.path.lastIndexOf('/') + 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              choice.songCount == 1 ? '1 song' : '${choice.songCount} songs',
              style: TextStyle(color: colors.mutedForeground),
            ),
            onTap: () => Navigator.of(context).pop(choice.path),
          ),
      ],
    );
  }
}
