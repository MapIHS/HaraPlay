import 'package:flutter/material.dart';

import '../../../core/artwork/song_artwork.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/utils/duration_format.dart';
import '../../library/presentation/widgets/library_row.dart';
import '../domain/playlist_models.dart';

/// The first song's artwork, or a music-list tile for an empty playlist.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.playlist,
    this.size = HaraSizes.songTileArtwork,
    this.shadow = false,
  });

  final PlaylistSummary playlist;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final songId = playlist.coverSongId;
    final large = size >= 120;
    if (songId == null) {
      return IconTile(
        icon: HaraIcons.listMusic,
        seed: playlist.id,
        size: size,
        shadow: shadow,
      );
    }
    return SongArtwork(
      songId: songId,
      albumId: playlist.coverAlbumId,
      version: playlist.coverVersion ?? 0,
      size: size,
      shadow: shadow,
      borderRadius: large ? HaraRadius.lg : HaraRadius.md,
      borderWidth: large ? HaraBorder.regular : HaraBorder.thin,
    );
  }
}

/// "12 songs · 48 min", or "Empty".
String playlistSubtitle(PlaylistSummary playlist) {
  final count = playlist.songCount;
  if (count == 0) return 'Empty';
  final songs = count == 1 ? '1 song' : '$count songs';
  return '$songs · ${formatTotalDuration(playlist.duration)}';
}
