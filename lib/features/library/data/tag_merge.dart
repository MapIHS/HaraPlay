import '../../../core/utils/text_normalize.dart';

/// The tag fields that a file's own tags can correct.
class SongTags {
  const SongTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.year,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int? year;

  @override
  bool operator ==(Object other) =>
      other is SongTags &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.albumArtist == albumArtist &&
      other.genre == genre &&
      other.trackNumber == trackNumber &&
      other.discNumber == discNumber &&
      other.year == year;

  @override
  int get hashCode => Object.hash(
    title,
    artist,
    album,
    albumArtist,
    genre,
    trackNumber,
    discNumber,
    year,
  );

  @override
  String toString() =>
      'SongTags($title, $artist, $album, $albumArtist, $genre, '
      '$trackNumber, $discNumber, $year)';
}

/// Combines MediaStore's tags with the file's own [file] tags:
/// - missing values are filled from the file; existing ones always win;
/// - text is replaced only when the two differ solely in non-ASCII
///   characters, which is what a code-page mix-up looks like.
SongTags mergeTags(SongTags mediaStore, SongTags file) => SongTags(
  title: _mergeText(mediaStore.title, file.title),
  artist: _mergeText(mediaStore.artist, file.artist),
  album: _mergeText(mediaStore.album, file.album),
  albumArtist: mediaStore.albumArtist ?? file.albumArtist,
  genre: mediaStore.genre ?? file.genre,
  trackNumber: mediaStore.trackNumber ?? file.trackNumber,
  discNumber: mediaStore.discNumber ?? file.discNumber,
  year: mediaStore.year ?? file.year,
);

String? _mergeText(String? mediaStore, String? file) {
  if (mediaStore == null) return file;
  if (file == null || file == mediaStore) return mediaStore;
  return isEncodingVariant(mediaStore, file) ? file : mediaStore;
}

/// True when [a] and [b] have the same length, differ somewhere, and every
/// difference is between two non-ASCII characters ("Seńorita" vs
/// "Señorita").
bool isEncodingVariant(String a, String b) {
  if (a.length != b.length || a == b) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a.codeUnitAt(i);
    final y = b.codeUnitAt(i);
    if (x != y && (x <= 0x7F || y <= 0x7F)) return false;
  }
  return true;
}

/// Whether a song's MediaStore tags are worth checking against the file.
/// A missing album artist alone is not a reason: most files simply have
/// none. It is still filled in when the file is read for another reason.
bool needsFileTags(SongTags tags) =>
    tags.year == null ||
    tags.genre == null ||
    tags.trackNumber == null ||
    [tags.title, tags.artist, tags.album].nonNulls.any(hasNonAscii);
