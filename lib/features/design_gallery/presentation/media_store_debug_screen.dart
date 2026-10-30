import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/platform/media_store_channel.dart';
import '../../../core/platform/media_store_song.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/artwork_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_icon_button.dart';

final _songsProvider = FutureProvider.autoDispose<List<MediaStoreSong>>(
  (ref) => ref.watch(mediaSourceProvider).querySongs(),
);

/// Debug screen listing every song the MediaStore channel returns, with all
/// parsed fields and artwork. Reachable from Settings → Developer.
class MediaStoreDebugScreen extends ConsumerWidget {
  const MediaStoreDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(_songsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (songs) {
          AsyncData(:final value) => 'MediaStore (${value.length})',
          _ => 'MediaStore',
        }),
        actions: [
          HaraIconButton(
            icon: HaraIcons.refreshCw,
            tooltip: 'Query again',
            onPressed: () => ref.invalidate(_songsProvider),
          ),
          const SizedBox(width: HaraSpacing.xs),
        ],
      ),
      body: switch (songs) {
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: HaraIcons.music,
          title: 'No songs',
          message: 'MediaStore returned no music files.',
        ),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.all(HaraSpacing.gutter),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: HaraSpacing.md),
          itemBuilder: (context, i) => _SongDetails(song: value[i]),
        ),
        AsyncError(:final error) => EmptyState(
          icon: HaraIcons.circleAlert,
          title: 'Query failed',
          message: '$error',
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SongDetails extends ConsumerStatefulWidget {
  const _SongDetails({required this.song});

  final MediaStoreSong song;

  @override
  ConsumerState<_SongDetails> createState() => _SongDetailsState();
}

class _SongDetailsState extends ConsumerState<_SongDetails> {
  late final Future<Uint8List?> _artwork = ref
      .read(mediaSourceProvider)
      .loadArtwork(
        songId: widget.song.id,
        albumId: widget.song.albumId,
        sizePx: 192,
      );

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final colors = HaraColors.of(context);
    final mono = HaraTextStyles.of(context).mono;
    final rows = <(String, Object?)>[
      ('id', song.id),
      ('artist', song.artist),
      ('album', song.album),
      ('albumArtist', song.albumArtist),
      ('albumId', song.albumId),
      ('genre', song.genre),
      ('track', _trackLabel(song)),
      ('year', song.year),
      ('duration', formatDuration(song.duration)),
      ('size', '${(song.sizeBytes / 1024).toStringAsFixed(0)} KB'),
      ('mime', song.mimeType),
      ('folder', song.folderName),
      ('added', song.dateAdded.toIso8601String()),
    ];

    return Container(
      padding: const EdgeInsets.all(HaraSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(HaraRadius.md),
        border: Border.all(color: colors.border, width: HaraBorder.thin),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Uint8List?>(
            future: _artwork,
            builder: (context, snapshot) => ArtworkImage(
              size: 64,
              seed: song.id,
              image: snapshot.data == null ? null : MemoryImage(snapshot.data!),
            ),
          ),
          const SizedBox(width: HaraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: HaraSpacing.xs),
                for (final (label, value) in rows)
                  Text('$label: ${value ?? '—'}', style: mono),
                Text(song.path, style: mono.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _trackLabel(MediaStoreSong song) {
    if (song.trackNumber == null) return null;
    return song.discNumber == null
        ? '${song.trackNumber}'
        : '${song.discNumber}-${song.trackNumber}';
  }
}
