import 'package:flutter/material.dart';

import '../../../../core/artwork/song_artwork.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/hara_tokens.dart';
import '../../../../core/theme/hara_typography.dart';
import '../../../../core/widgets/song_tile.dart';
import '../../domain/library_models.dart';

/// "Artist · Album" with the unknown placeholders.
String songSubtitle(SongRow song, {bool showAlbum = true}) => [
  song.artist ?? unknownArtist,
  if (showAlbum) song.album ?? unknownAlbum,
].join(' · ');

/// A [SongTile] for a library song: artwork (or the track number inside an
/// album), title, artist and album, duration.
class LibrarySongTile extends StatelessWidget {
  const LibrarySongTile({
    super.key,
    required this.song,
    this.showAlbum = true,
    this.showTrackNumber = false,
    this.subtitle,
    this.onTap,
  });

  final SongRow song;
  final bool showAlbum;

  /// Album lists show the track number instead of the artwork.
  final bool showTrackNumber;

  /// Replaces the default "Artist · Album" line.
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SongTile(
      title: song.title,
      subtitle: subtitle ?? songSubtitle(song, showAlbum: showAlbum),
      duration: Duration(milliseconds: song.durationMs),
      onTap: onTap,
      leading: showTrackNumber
          ? SizedBox(
              width: 28,
              child: Text(
                song.trackNumber?.toString() ?? '–',
                textAlign: TextAlign.center,
                style: HaraTextStyles.of(context).monoStrong,
              ),
            )
          : SongArtwork(
              songId: song.id,
              albumId: song.albumId,
              version: song.dateModified,
              size: HaraSizes.songTileArtwork,
            ),
    );
  }
}
