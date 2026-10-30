import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_chip.dart';
import '../../player/presentation/play_actions.dart';
import 'library_providers.dart';
import 'widgets/album_card.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_scaffold.dart';
import 'widgets/library_song_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final int albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(albumProvider(albumId)).value;
    return DetailScaffold(
      songs: ref.watch(albumSongsProvider(albumId)),
      header: (songs) {
        final first = songs.first;
        final artist = album?.artist;
        // Link only to an artist page that has these songs.
        final linkable =
            album != null &&
            !album.variousArtists &&
            songs.any((s) => s.artist == artist);
        return DetailHeader(
          visual: SongArtwork(
            songId: album?.coverSongId ?? first.id,
            albumId: albumId,
            version: album?.coverVersion ?? first.dateModified,
            size: DetailHeader.visualSize,
            shadow: true,
            borderRadius: HaraRadius.lg,
            borderWidth: HaraBorder.regular,
          ),
          kicker: 'Album',
          title: album == null ? '' : albumTitle(album),
          subtitle: album == null ? null : 'by ${albumArtist(album)}',
          onSubtitleTap: linkable
              ? () => context.push(AppRoutes.artist(artist))
              : null,
          chips: [
            if (album?.year != null)
              HaraChip(value: '${album!.year}', label: 'Year'),
            ...countChips(songs, noun: 'Track'),
          ],
          onPlay: () => playSongs(ref, songs, source: PlaySource.album),
          onShuffle: () => shuffleSongs(ref, songs, source: PlaySource.album),
        );
      },
      songList: (songs) {
        final multiDisc = songs.map((s) => s.discNumber).toSet().length > 1;
        final rows = <Object>[];
        int? disc = -1;
        for (final song in songs) {
          if (multiDisc && song.discNumber != disc) {
            disc = song.discNumber;
            rows.add(disc == null ? 'Other' : 'Disc $disc');
          }
          rows.add(song);
        }
        return SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => switch (rows[i]) {
            final SongRow song => SizedBox(
              height: HaraSizes.songTileHeight,
              child: LibrarySongTile(
                song: song,
                showAlbum: false,
                showTrackNumber: true,
                onTap: () => playSongs(
                  ref,
                  songs,
                  index: songs.indexOf(song),
                  source: PlaySource.album,
                ),
              ),
            ),
            final String label => _DiscHeader(label: label),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _DiscHeader extends StatelessWidget {
  const _DiscHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HaraSpacing.gutter,
          HaraSpacing.lg,
          HaraSpacing.gutter,
          HaraSpacing.xs,
        ),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium!
              .copyWith(color: HaraColors.of(context).mutedForeground),
        ),
      ),
    );
  }
}
