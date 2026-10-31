import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../library/presentation/widgets/library_row.dart';
import '../domain/playlist_models.dart';
import 'playlist_cover.dart';
import 'playlist_dialogs.dart';
import 'playlist_providers.dart';

/// Lets the user pick a playlist (or create one) and appends [songIds] to
/// it. [showFeedback] confirms with a snackbar.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<int> songIds, {
  bool showFeedback = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(playlistsDaoProvider);

  final choice = await showHaraSheet<_Choice>(
    context: context,
    title: 'Add to playlist',
    builder: (_) =>
        _PlaylistPicker(songId: songIds.length == 1 ? songIds.single : null),
  );
  if (choice == null || !context.mounted) return;

  final int playlistId;
  final String name;
  switch (choice) {
    case _NewPlaylist():
      final picked = await showPlaylistNameDialog(
        context,
        title: 'New playlist',
        confirmLabel: 'Create',
      );
      if (picked == null) return;
      name = picked;
      playlistId = await dao.create(name, at: DateTime.now());
    case _Existing(:final playlist):
      playlistId = playlist.id;
      name = playlist.name;
  }
  await dao.addSongs(playlistId, songIds, at: DateTime.now());
  if (!showFeedback) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Added to $name')));
}

sealed class _Choice {
  const _Choice();
}

class _NewPlaylist extends _Choice {
  const _NewPlaylist();
}

class _Existing extends _Choice {
  const _Existing(this.playlist);

  final PlaylistSummary playlist;
}

class _PlaylistPicker extends ConsumerWidget {
  const _PlaylistPicker({required this.songId});

  /// Set when adding a single song: marks the playlists that have it.
  final int? songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final id = songId;
    final containing = id == null
        ? const <int>{}
        : ref.watch(playlistsContainingProvider(id)).value ?? const <int>{};
    void choose(_Choice choice) => Navigator.of(context).pop(choice);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickerRow(
          leading: const IconTile(icon: HaraIcons.plus, seed: 0),
          title: 'New playlist',
          onTap: () => choose(const _NewPlaylist()),
        ),
        for (final playlist in playlists)
          _PickerRow(
            leading: PlaylistCover(playlist: playlist),
            title: playlist.name,
            subtitle: containing.contains(playlist.id)
                ? 'Already has this song · ${playlistSubtitle(playlist)}'
                : playlistSubtitle(playlist),
            added: containing.contains(playlist.id),
            onTap: () => choose(_Existing(playlist)),
          ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.added = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: [title, ?subtitle].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: HaraSizes.rowHeightOf(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
            child: Row(
              children: [
                leading,
                const SizedBox(width: HaraSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (added)
                  Icon(
                    HaraIcons.check,
                    size: HaraSizes.iconSmall,
                    color: colors.emphasis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
