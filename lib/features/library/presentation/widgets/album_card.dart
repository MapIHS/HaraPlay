import 'package:flutter/material.dart';

import '../../../../core/artwork/song_artwork.dart';
import '../../../../core/theme/hara_tokens.dart';
import '../../domain/library_models.dart';

/// Album label lines used by cards and headers.
String albumTitle(AlbumSummary album) => album.title ?? unknownAlbum;

String albumArtist(AlbumSummary album) =>
    album.variousArtists ? variousArtists : album.artist ?? unknownArtist;

/// A grid card: square artwork with a hard shadow, title and artist.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, required this.onTap});

  final AlbumSummary album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: true,
      label: '${albumTitle(album)}, ${albumArtist(album)}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Room for the hard shadow inside the grid cell.
              padding: const EdgeInsets.only(
                right: HaraShadow.offset,
                bottom: HaraShadow.offset,
              ),
              child: SongArtwork(
                songId: album.coverSongId,
                albumId: album.albumId,
                version: album.coverVersion,
                shadow: true,
                borderRadius: HaraRadius.lg,
                borderWidth: HaraBorder.regular,
              ),
            ),
            const SizedBox(height: HaraSpacing.sm),
            Text(
              albumTitle(album),
              style: textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              albumArtist(album),
              style: textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
