import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/song_artwork.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/hara_tokens.dart';
import '../../../../core/theme/hara_typography.dart';
import '../../../../core/widgets/song_tile.dart';
import '../../../player/domain/queue_song.dart';
import '../../../player/presentation/player_providers.dart';
import '../../../player/presentation/song_actions_sheet.dart';
import '../../../playlists/presentation/playlist_providers.dart';
import '../../domain/library_models.dart';

/// "Artist · Album" with the unknown placeholders.
String songSubtitle(SongRow song, {bool showAlbum = true}) => [
  song.artist ?? unknownArtist,
  if (showAlbum) song.album ?? unknownAlbum,
].join(' · ');

/// A [SongTile] for a library song: artwork (or the track number inside an
/// album), title, artist and album, a heart if liked, duration.
/// Highlighted while playing.
class LibrarySongTile extends ConsumerWidget {
  const LibrarySongTile({
    super.key,
    required this.song,
    this.showAlbum = true,
    this.showTrackNumber = false,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.onRemoveFromPlaylist,
  });

  final SongRow song;
  final bool showAlbum;

  /// Album lists show the track number instead of the artwork.
  final bool showTrackNumber;

  /// Replaces the default "Artist · Album" line.
  final String? subtitle;
  final VoidCallback? onTap;

  /// After the "more" button (a playlist's drag handle).
  final Widget? trailing;

  /// Adds "Remove from this playlist" to the actions.
  final VoidCallback? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentSongIdProvider) == song.id;
    void actions() => showSongActions(
      context,
      ref,
      QueueSong.fromRow(song),
      onRemoveFromPlaylist: onRemoveFromPlaylist,
    );
    return SongTile(
      selected: current,
      liked: ref.watch(isLikedProvider(song.id)),
      trailing: trailing,
      onMore: actions,
      onLongPress: actions,
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
