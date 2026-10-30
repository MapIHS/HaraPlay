import 'tag_merge.dart';

/// Artist and title guessed from a file name like "Artist - Title".
class FilenameTags {
  const FilenameTags({required this.artist, required this.title});

  final String artist;
  final String title;
}

// "01 - ", "01. ", "1) ", "01_ " or a zero-padded "01 ". A bare "50 " is not
// stripped, so names like "50 Cent - In Da Club" survive.
final _leadingTrack = RegExp(r'^(?:\d{1,3}\s*[.)\-–—_]\s*|0\d\s+)');
final _separator = RegExp(r'\s+[-–—]\s+');
final _website = RegExp(
  r'(?:^|\W)www\.|\.(?:com|net|org|io|co|me|tv|cc|to|info|xyz)(?:\W|$)',
  caseSensitive: false,
);
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _bracketOnly = RegExp(r'^(?:\(.*\)|\[.*\])$');

// Download noise at the end of a title: "(Lyrics)", "[Official Video]", …
final _trailingNoise = RegExp(
  r'\s*[(\[]\s*(?:lyrics?|lyric video|official video|official music video|'
  r'official audio|audio|hd|hq)\s*[)\]]\s*$',
  caseSensitive: false,
);
final _letter = RegExp(r'\p{L}', unicode: true);

/// Parses [fileStem] (the file name without extension). Returns null unless
/// the pattern is unambiguous: exactly one spaced dash (a trailing part that
/// is only a bracket joins the title), a plausible artist (has a letter, at
/// most 60 characters, not a website) and a non-empty title. Download noise
/// like "(Lyrics)" is stripped from the title.
FilenameTags? inferFromFileName(String fileStem) {
  var name = fileStem.trim();
  final track = _leadingTrack.firstMatch(name);
  if (track != null) name = name.substring(track.end);

  final parts = name.split(_separator).map((p) => p.trim()).toList();
  // "Artist - Title - (Lyrics)": a last part that is only a bracket belongs
  // to the title.
  final notes = <String>[];
  while (parts.length > 2 && _bracketOnly.hasMatch(parts.last)) {
    notes.insert(0, parts.removeLast());
  }
  if (notes.isNotEmpty) parts.last = [parts.last, ...notes].join(' ');
  if (parts.length != 2) return null;
  final artist = parts[0];
  final title = stripDownloadNoise(parts[1]);

  if (artist.isEmpty || artist.length > 60) return null;
  if (!_letter.hasMatch(artist) || _website.hasMatch(artist)) return null;
  if (!_letterOrDigit.hasMatch(title)) return null;
  return FilenameTags(artist: artist, title: title);
}

/// Removes trailing download noise such as "(Lyrics)" or "[Official Video]"
/// (repeatedly), keeping any other bracket text. Never returns an empty
/// title. Only used for titles guessed from file names.
String stripDownloadNoise(String title) {
  var result = title;
  while (true) {
    final stripped = result.replaceFirst(_trailingNoise, '');
    if (stripped == result || !_letterOrDigit.hasMatch(stripped)) break;
    result = stripped;
  }
  return result.trim();
}

/// The file name of [path] without directory or extension.
String fileStem(String path) {
  final name = path.substring(path.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// Applies [inferFromFileName] to [tags] only when the song has no artist
/// tag and no real title tag (MediaStore then reports the file name as the
/// title). Real tags are never overwritten.
(SongTags, bool fromFilename) withFilenameTags(SongTags tags, String path) {
  final stem = fileStem(path);
  if (tags.artist != null) return (tags, false);
  if (tags.title != null && tags.title != stem) return (tags, false);
  final inferred = inferFromFileName(stem);
  if (inferred == null) return (tags, false);
  return (
    SongTags(
      title: inferred.title,
      artist: inferred.artist,
      album: tags.album,
      albumArtist: tags.albumArtist,
      genre: tags.genre,
      trackNumber: tags.trackNumber,
      discNumber: tags.discNumber,
      year: tags.year,
    ),
    true,
  );
}

/// [mergeTags] for the song at [path]. A MediaStore title equal to the file
/// name is only a placeholder (no title tag), so the file's title wins.
SongTags mergeTagsForPath(SongTags mediaStore, SongTags file, String path) {
  final placeholder = mediaStore.title == fileStem(path);
  final merged = mergeTags(
    placeholder ? _withTitle(mediaStore, null) : mediaStore,
    file,
  );
  return merged.title == null ? _withTitle(merged, mediaStore.title) : merged;
}

SongTags _withTitle(SongTags tags, String? title) => SongTags(
  title: title,
  artist: tags.artist,
  album: tags.album,
  albumArtist: tags.albumArtist,
  genre: tags.genre,
  trackNumber: tags.trackNumber,
  discNumber: tags.discNumber,
  year: tags.year,
);
