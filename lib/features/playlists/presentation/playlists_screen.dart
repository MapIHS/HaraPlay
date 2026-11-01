import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_card.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../../core/widgets/heart_mark.dart';
import '../../../core/widgets/section_header.dart';
import '../data/m3u_service.dart';
import '../domain/playlist_models.dart';
import 'playlist_cover.dart';
import 'playlist_dialogs.dart';
import 'playlist_providers.dart';

/// Playlists tab: Liked songs first, then the user's playlists by name.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final likedCount = ref.watch(
      likedSongIdsProvider.select((ids) => ids.value?.length ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          HaraIconButton(
            icon: HaraIcons.fileInput,
            tooltip: 'Import playlist (.m3u)',
            onPressed: () => importPlaylist(context, ref),
          ),
          HaraIconButton(
            icon: HaraIcons.plus,
            tooltip: 'New playlist',
            onPressed: () => createPlaylist(context, ref),
          ),
          const SizedBox(width: HaraSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              HaraSpacing.sm,
              HaraSpacing.gutter,
              HaraSpacing.md,
            ),
            child: LikedSongsCard(
              count: likedCount,
              onTap: () => context.push(AppRoutes.likedSongs),
            ),
          ),
          const SectionHeader(title: 'Your playlists'),
          ...switch (playlists) {
            AsyncData(:final value) when value.isEmpty => [
              _NoPlaylists(onCreate: () => createPlaylist(context, ref)),
            ],
            AsyncData(:final value) => [
              for (final playlist in value)
                _PlaylistRow(
                  playlist: playlist,
                  onTap: () => context.push(AppRoutes.playlist(playlist.id)),
                  onMore: () => showPlaylistActions(context, ref, playlist),
                ),
            ],
            AsyncError() => [
              const Padding(
                padding: EdgeInsets.all(HaraSpacing.gutter),
                child: Text("Couldn't load your playlists."),
              ),
            ],
            AsyncLoading() => [
              const Padding(
                padding: EdgeInsets.all(HaraSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          },
        ],
      ),
    );
  }
}

/// Asks for a name, creates the playlist and opens it.
Future<void> createPlaylist(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final name = await showPlaylistNameDialog(
    context,
    title: 'New playlist',
    confirmLabel: 'Create',
  );
  if (name == null) return;
  final id = await ref
      .read(playlistsDaoProvider)
      .create(name, at: DateTime.now());
  await router.push(AppRoutes.playlist(id));
}

Future<void> _export(
  BuildContext context,
  WidgetRef ref,
  PlaylistSummary playlist,
) async {
  final messenger = ScaffoldMessenger.of(context);
  String? message;
  try {
    final saved = await ref.read(m3uServiceProvider).export(playlist);
    if (saved != null) message = 'Saved "$saved".';
  } on Object {
    message = "Couldn't save the playlist. Please try again.";
  }
  if (message == null) return; // Cancelled.
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Picks an `.m3u` file, makes a playlist of the songs found and opens it.
Future<void> importPlaylist(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  M3uImport? result;
  try {
    result = await ref.read(m3uServiceProvider).import();
  } on Object {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("Couldn't read that file. Is it an .m3u playlist?"),
        ),
      );
    return;
  }
  if (result == null) return; // Cancelled.
  final id = result.playlistId;
  // Not awaited: push completes only when the page is closed.
  if (id != null) unawaited(router.push(AppRoutes.playlist(id)));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(describeImport(result))));
}

/// Rename / export / delete for one playlist. [onDeleted] runs after a delete (the
/// detail screen closes itself).
Future<void> showPlaylistActions(
  BuildContext context,
  WidgetRef ref,
  PlaylistSummary playlist, {
  VoidCallback? onDeleted,
  VoidCallback? onAddSongs,
}) async {
  final dao = ref.read(playlistsDaoProvider);
  final action = await showHaraSheet<_PlaylistAction>(
    context: context,
    title: playlist.name,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onAddSongs != null)
          const _SheetAction(
            icon: HaraIcons.listPlus,
            label: 'Add songs',
            value: _PlaylistAction.addSongs,
          ),
        const _SheetAction(
          icon: HaraIcons.pencil,
          label: 'Rename',
          value: _PlaylistAction.rename,
        ),
        const _SheetAction(
          icon: HaraIcons.fileOutput,
          label: 'Export as .m3u',
          value: _PlaylistAction.export,
        ),
        const _SheetAction(
          icon: HaraIcons.trash2,
          label: 'Delete playlist',
          value: _PlaylistAction.delete,
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _PlaylistAction.addSongs:
      onAddSongs?.call();
    case _PlaylistAction.rename:
      final name = await showPlaylistNameDialog(
        context,
        title: 'Rename playlist',
        confirmLabel: 'Save',
        initial: playlist.name,
      );
      if (name != null && name != playlist.name) {
        await dao.rename(playlist.id, name, at: DateTime.now());
      }
    case _PlaylistAction.export:
      await _export(context, ref, playlist);
    case _PlaylistAction.delete:
      if (!await confirmDeletePlaylist(context, playlist.name)) return;
      onDeleted?.call();
      await dao.deletePlaylist(playlist.id);
  }
}

enum _PlaylistAction { addSongs, rename, export, delete }

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final _PlaylistAction value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(value),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
            child: Row(
              children: [
                Icon(icon, size: HaraSizes.iconSmall),
                const SizedBox(width: HaraSpacing.lg),
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The brand-filled "Liked songs" card (Playlists tab, Home).
class LikedSongsCard extends StatelessWidget {
  const LikedSongsCard({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final subtitle = count == 1 ? '1 song' : '$count songs';
    return HaraCard(
      onTap: onTap,
      color: colors.primary,
      semanticLabel: 'Liked songs, $subtitle',
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(HaraRadius.md),
              border: Border.all(color: colors.border, width: HaraBorder.thin),
            ),
            child: const Center(child: HeartMark(size: 28)),
          ),
          const SizedBox(width: HaraSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liked songs',
                  style: textTheme.titleLarge!.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium!.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(HaraIcons.chevronRight, color: colors.onPrimary),
        ],
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.onTap,
    required this.onMore,
  });

  final PlaylistSummary playlist;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = playlistSubtitle(playlist);
    return Semantics(
      button: true,
      label: '${playlist.name}, $subtitle',
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        child: SizedBox(
          height: HaraSizes.rowHeightOf(context),
          child: Padding(
            padding: const EdgeInsets.only(
              left: HaraSpacing.gutter,
              right: HaraSpacing.xs,
            ),
            child: Row(
              children: [
                PlaylistCover(playlist: playlist),
                const SizedBox(width: HaraSpacing.md),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                HaraIconButton(
                  icon: HaraIcons.ellipsisVertical,
                  tooltip: 'Playlist options',
                  onPressed: onMore,
                  iconSize: HaraSizes.iconSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPlaylists extends StatelessWidget {
  const _NoPlaylists({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaraSpacing.gutter,
        HaraSpacing.xs,
        HaraSpacing.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No playlists yet. Make one here, or add a song to a new '
            'playlist from its ⋮ menu.',
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(height: HaraSpacing.md),
          HaraButton(
            label: 'New playlist',
            icon: HaraIcons.plus,
            variant: HaraButtonVariant.secondary,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
