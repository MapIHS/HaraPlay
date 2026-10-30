import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/library_models.dart';
import 'library_providers.dart';
import 'widgets/album_card.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_scaffold.dart';
import 'widgets/library_song_tile.dart';
import 'widgets/playback_soon.dart';

/// An artist's albums and songs. [name] null is "Unknown artist".
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.name});

  final String? name;

  static const double _albumCardWidth = 136;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(artistAlbumsProvider(name)).value ?? const [];
    return DetailScaffold(
      songs: ref.watch(artistSongsProvider(name)),
      header: (songs) => DetailHeader(
        visual: SongArtwork(
          songId: songs.first.id,
          albumId: songs.first.albumId,
          version: songs.first.dateModified,
          size: DetailHeader.visualSize,
          shadow: true,
          borderRadius: HaraRadius.pill,
          borderWidth: HaraBorder.regular,
        ),
        kicker: 'Artist',
        title: name ?? unknownArtist,
        chips: [
          ...countChips(songs),
          if (albums.isNotEmpty)
            HaraChip(
              value: '${albums.length}',
              label: albums.length == 1 ? 'Album' : 'Albums',
            ),
        ],
        onPlay: () => showPlaybackComingSoon(context),
        onShuffle: () => showPlaybackComingSoon(context),
      ),
      extraSlivers: [
        // A row of albums is only useful when there is more than one.
        if (albums.length > 1) ...[
          const SliverToBoxAdapter(child: SectionHeader(title: 'Albums')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: _albumCardWidth + HaraSpacing.sm + AlbumCard.labelHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: HaraSpacing.gutter,
                ),
                itemCount: albums.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: HaraSpacing.lg),
                itemBuilder: (context, i) => SizedBox(
                  width: _albumCardWidth,
                  child: AlbumCard(
                    album: albums[i],
                    onTap: () {
                      final id = albums[i].albumId;
                      if (id != null) context.push(AppRoutes.album(id));
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SectionHeader(title: 'Songs')),
      ],
      songList: (songs) => SliverFixedExtentList(
        itemExtent: HaraSizes.songTileHeight,
        delegate: SliverChildBuilderDelegate(
          (context, i) => LibrarySongTile(
            song: songs[i],
            subtitle: songs[i].album ?? unknownAlbum,
          ),
          childCount: songs.length,
        ),
      ),
    );
  }
}
