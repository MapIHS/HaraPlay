/// An album as shown in the grid and its detail header.
class AlbumSummary {
  const AlbumSummary({
    required this.albumId,
    required this.title,
    required this.artist,
    required this.variousArtists,
    required this.year,
    required this.songCount,
    required this.duration,
    required this.coverSongId,
    required this.coverVersion,
  });

  final int? albumId;
  final String? title;

  /// The album artist, or the one track artist all songs share.
  final String? artist;

  /// Songs are by several artists and there is no album artist tag.
  final bool variousArtists;
  final int? year;
  final int songCount;
  final Duration duration;

  /// A song whose artwork represents the album, and its date_modified.
  final int coverSongId;
  final int coverVersion;
}

class ArtistSummary {
  const ArtistSummary({
    required this.name,
    required this.songCount,
    required this.albumCount,
    required this.coverSongId,
    required this.coverAlbumId,
    required this.coverVersion,
  });

  /// Null groups the songs without an artist.
  final String? name;
  final int songCount;
  final int albumCount;
  final int coverSongId;
  final int? coverAlbumId;
  final int coverVersion;
}

class FolderSummary {
  const FolderSummary({
    required this.path,
    required this.name,
    required this.songCount,
  });

  final String path;
  final String name;
  final int songCount;
}

class GenreSummary {
  const GenreSummary({required this.name, required this.songCount});

  final String name;
  final int songCount;
}

/// Display names for missing tags.
const unknownArtist = 'Unknown artist';
const unknownAlbum = 'Unknown album';
const variousArtists = 'Various artists';
