import '../../../core/database/app_database.dart';

/// A playlist row with its totals and cover (the first entry's song).
class PlaylistSummary {
  const PlaylistSummary({
    required this.id,
    required this.name,
    required this.songCount,
    required this.duration,
    this.coverSongId,
    this.coverAlbumId,
    this.coverVersion,
  });

  final int id;
  final String name;
  final int songCount;
  final Duration duration;

  /// Null for an empty playlist.
  final int? coverSongId;
  final int? coverAlbumId;
  final int? coverVersion;
}

/// One position in a playlist. [entryId] tells duplicates apart.
class PlaylistEntry {
  const PlaylistEntry({required this.entryId, required this.song});

  final int entryId;
  final SongRow song;
}

/// What `PlaylistsDao.removeEntry` took out, so it can be put back.
class RemovedEntry {
  const RemovedEntry({
    required this.playlistId,
    required this.songId,
    required this.songPath,
    required this.index,
    required this.addedAt,
  });

  final int playlistId;
  final int songId;
  final String songPath;

  /// Index in the playlist's order when it was removed.
  final int index;
  final int addedAt;
}

/// Longest playlist name we accept.
const maxPlaylistNameLength = 100;

/// The trimmed name, or null if it can't be used.
String? cleanPlaylistName(String input) {
  final name = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.length > maxPlaylistNameLength) return null;
  return name;
}
