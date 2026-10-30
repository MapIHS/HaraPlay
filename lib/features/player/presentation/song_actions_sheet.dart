import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../library/presentation/library_providers.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';

/// Shows the actions for [song] (long-press or ⋯ on a song, ⋯ in Now
/// Playing). [beforeNavigate] runs before "Go to album / artist" leaves
/// (Now Playing collapses itself). [showFeedback] shows a snackbar after
/// queue actions; off where a snackbar would be hidden (Now Playing).
Future<void> showSongActions(
  BuildContext context,
  WidgetRef ref,
  QueueSong song, {
  VoidCallback? beforeNavigate,
  bool showFeedback = true,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final player = ref.read(playerProvider);

  void feedback(String message) {
    if (!showFeedback) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final action = await showHaraSheet<_SongAction>(
    context: context,
    builder: (_) => _SongActions(song: song),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _SongAction.playNext:
      await player.playNext([song]);
      feedback('Playing next: ${song.title}');
    case _SongAction.addToQueue:
      await player.addToQueue([song]);
      feedback('Added to queue: ${song.title}');
    case _SongAction.goToAlbum:
      beforeNavigate?.call();
      await router.push(AppRoutes.album(song.albumId!));
    case _SongAction.goToArtist:
      beforeNavigate?.call();
      await router.push(AppRoutes.artist(song.artist));
    case _SongAction.info:
      if (!context.mounted) return;
      await showHaraSheet<void>(
        context: context,
        title: 'Song info',
        builder: (_) => SongInfo(songId: song.id),
      );
  }
}

enum _SongAction { playNext, addToQueue, goToAlbum, goToArtist, info }

class _SongActions extends StatelessWidget {
  const _SongActions({required this.song});

  final QueueSong song;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    void choose(_SongAction action) => Navigator.of(context).pop(action);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Which song these actions are for.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HaraSpacing.gutter,
            0,
            HaraSpacing.gutter,
            HaraSpacing.md,
          ),
          child: Row(
            children: [
              SongArtwork(
                songId: song.id,
                albumId: song.albumId,
                version: song.version,
                size: HaraSizes.songTileArtwork,
              ),
              const SizedBox(width: HaraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${song.displayArtist} · ${song.displayAlbum}',
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        _ActionRow(
          icon: HaraIcons.listStart,
          label: 'Play next',
          onTap: () => choose(_SongAction.playNext),
        ),
        _ActionRow(
          icon: HaraIcons.listEnd,
          label: 'Add to queue',
          onTap: () => choose(_SongAction.addToQueue),
        ),
        if (song.albumId != null)
          _ActionRow(
            icon: HaraIcons.disc3,
            label: 'Go to album',
            onTap: () => choose(_SongAction.goToAlbum),
          ),
        _ActionRow(
          icon: HaraIcons.user,
          label: 'Go to artist',
          onTap: () => choose(_SongAction.goToArtist),
        ),
        _ActionRow(
          icon: HaraIcons.info,
          label: 'Song info',
          onTap: () => choose(_SongAction.info),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
            child: Row(
              children: [
                Icon(icon, size: HaraSizes.iconSmall),
                const SizedBox(width: HaraSpacing.lg),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// File details for one song.
class SongInfo extends ConsumerWidget {
  const SongInfo({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(songByIdProvider(songId))) {
      AsyncData(value: final song?) => _SongInfoTable(song: song),
      AsyncData() => const Padding(
        padding: EdgeInsets.all(HaraSpacing.gutter),
        child: Text('This song is no longer on this phone.'),
      ),
      AsyncError() => const Padding(
        padding: EdgeInsets.all(HaraSpacing.gutter),
        child: Text("Couldn't read this song's details."),
      ),
      AsyncLoading() => const Padding(
        padding: EdgeInsets.all(HaraSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// "FLAC" from the file extension, with the MIME type as a fallback.
String formatLabel(String path, String? mimeType) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf('/');
  if (dot > slash && dot < path.length - 1) {
    return path.substring(dot + 1).toUpperCase();
  }
  return mimeType ?? 'Unknown';
}

/// "5.2 MB" / "870 KB".
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).round()} KB';
}

class _SongInfoTable extends StatelessWidget {
  const _SongInfoTable({required this.song});

  final SongRow song;

  @override
  Widget build(BuildContext context) {
    final added = DateTime.fromMillisecondsSinceEpoch(song.dateAdded).toLocal();
    final rows = <(String, String)>[
      ('Title', song.title),
      if (song.artist != null) ('Artist', song.artist!),
      if (song.album != null) ('Album', song.album!),
      if (song.albumArtist != null) ('Album artist', song.albumArtist!),
      if (song.trackNumber != null)
        (
          'Track',
          song.discNumber == null
              ? '${song.trackNumber}'
              : '${song.trackNumber} (disc ${song.discNumber})',
        ),
      if (song.year != null) ('Year', '${song.year}'),
      if (song.genre != null) ('Genre', song.genre!),
      ('Length', formatDuration(Duration(milliseconds: song.durationMs))),
      ('Format', formatLabel(song.path, song.mimeType)),
      ('Size', formatFileSize(song.sizeBytes)),
      (
        'Added',
        '${added.year}-${added.month.toString().padLeft(2, '0')}-'
            '${added.day.toString().padLeft(2, '0')}',
      ),
      if (song.nameFromFilename)
        ('Note', 'Artist and title from the file name'),
    ];
    final textTheme = Theme.of(context).textTheme;
    final colors = HaraColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: HaraSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      label.toUpperCase(),
                      style: textTheme.labelMedium!.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                  Expanded(child: Text(value, style: textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: HaraSpacing.sm),
          Text(
            'FILE',
            style: textTheme.labelMedium!.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: HaraSpacing.xs),
          // Selectable, so the path can be copied.
          SelectableText(song.path, style: HaraTextStyles.of(context).mono),
          const SizedBox(height: HaraSpacing.lg),
        ],
      ),
    );
  }
}
