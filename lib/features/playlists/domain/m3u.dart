/// Reading and writing `.m3u` / `.m3u8` playlists (our own implementation
/// of the plain-text format: one location per line, `#` lines are
/// comments, `#EXTINF:<seconds>,<artist> - <title>` describes the next
/// line).
library;

/// One song in an exported playlist.
typedef M3uSong = ({
  String path,
  String title,
  String? artist,
  Duration duration,
});

/// The playlist as `.m3u` text: an `#EXTM3U` header, then `#EXTINF` and
/// the full path for each song. Lines end in `\n`; the text is meant to be
/// saved as UTF-8.
String writeM3u(List<M3uSong> songs) {
  final out = StringBuffer('#EXTM3U\n');
  for (final song in songs) {
    final name = song.artist == null || song.artist!.isEmpty
        ? song.title
        : '${song.artist} - ${song.title}';
    // A line break in a tag would end the line early.
    final clean = name.replaceAll(RegExp(r'[\r\n]+'), ' ');
    out
      ..write('#EXTINF:${song.duration.inSeconds},$clean\n')
      ..write('${song.path}\n');
  }
  return out.toString();
}

/// The song locations listed in an `.m3u` file, in order. `file://` URIs
/// become paths; web addresses are kept as they are (they never match a
/// song on the phone).
List<String> parseM3u(String text) {
  final locations = <String>[];
  for (var line in text.split(RegExp(r'\r\n|\r|\n'))) {
    line = line.trim();
    if (line.startsWith('﻿')) line = line.substring(1);
    if (line.isEmpty || line.startsWith('#')) continue;
    locations.add(_fromFileUri(line));
  }
  return locations;
}

String _fromFileUri(String location) {
  if (!location.toLowerCase().startsWith('file:')) return location;
  try {
    return Uri.parse(location).toFilePath();
  } on FormatException {
    return location;
  } on UnsupportedError {
    return location;
  }
}

/// The result of matching an imported playlist to the library.
typedef M3uMatch = ({List<int> songIds, List<String> missing});

/// Finds the library songs for [locations] from an `.m3u` file.
///
/// [songPaths] maps every song's ID to its absolute path. [playlistPath]
/// is where the `.m3u` file is, when known, for relative entries. Each
/// location is tried as:
/// 1. an absolute path (exact, then ignoring case: shared storage on
///    Android ignores case);
/// 2. a path relative to the playlist's folder;
/// 3. the same file name under the same parent folders, as long as one
///    song fits best (a playlist made on a computer or another phone).
M3uMatch matchM3u(
  List<String> locations,
  Map<int, String> songPaths, {
  String? playlistPath,
}) {
  final byPath = <String, int>{};
  final byLowerPath = <String, int>{};
  final byFileName = <String, List<(int, List<String>)>>{};
  for (final MapEntry(key: id, value: path) in songPaths.entries) {
    byPath.putIfAbsent(path, () => id);
    byLowerPath.putIfAbsent(path.toLowerCase(), () => id);
    final parts = _parts(path.toLowerCase());
    if (parts.isNotEmpty) {
      byFileName.putIfAbsent(parts.last, () => []).add((id, parts));
    }
  }
  final slash = playlistPath?.lastIndexOf('/') ?? -1;
  final playlistFolder = slash > 0 ? playlistPath!.substring(0, slash) : null;

  int? find(String location) {
    final path = location.replaceAll(r'\', '/');
    if (_isWebAddress(path)) return null;
    final candidates = [
      if (path.startsWith('/')) path,
      if (!path.startsWith('/') && playlistFolder != null)
        _normalize('$playlistFolder/$path'),
    ];
    for (final candidate in candidates) {
      final id = byPath[candidate] ?? byLowerPath[candidate.toLowerCase()];
      if (id != null) return id;
    }
    // Same file name; prefer the song sharing the most parent folders.
    final parts = _parts(path.toLowerCase());
    if (parts.isEmpty) return null;
    final sameName = byFileName[parts.last];
    if (sameName == null) return null;
    if (sameName.length == 1) return sameName.single.$1;
    var best = -1;
    int? bestId;
    var tie = false;
    for (final (id, songParts) in sameName) {
      final shared = _sharedTail(parts, songParts);
      if (shared > best) {
        best = shared;
        bestId = id;
        tie = false;
      } else if (shared == best) {
        tie = true;
      }
    }
    return tie ? null : bestId;
  }

  final ids = <int>[];
  final missing = <String>[];
  for (final location in locations) {
    final id = find(location);
    if (id == null) {
      missing.add(location);
    } else {
      ids.add(id);
    }
  }
  return (songIds: ids, missing: missing);
}

bool _isWebAddress(String location) =>
    RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(location);

List<String> _parts(String path) => [
  for (final part in path.split('/'))
    if (part.isNotEmpty && part != '.') part,
];

/// Resolves `.` and `..` in an absolute path.
String _normalize(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(part);
    }
  }
  return '/${out.join('/')}';
}

/// How many trailing path parts (file name included) two paths share.
int _sharedTail(List<String> a, List<String> b) {
  var n = 0;
  while (n < a.length &&
      n < b.length &&
      a[a.length - 1 - n] == b[b.length - 1 - n]) {
    n++;
  }
  return n;
}

/// A playlist name from an `.m3u` file name: "Road Trip.m3u8" → "Road
/// Trip". Falls back to "Imported playlist".
String playlistNameFromFile(String? fileName) {
  final name = (fileName ?? '')
      .replaceFirst(RegExp(r'\.m3u8?$', caseSensitive: false), '')
      .trim();
  return name.isEmpty ? 'Imported playlist' : name;
}

/// [name], or "name (2)", "name (3)"… if a playlist already has it.
String uniquePlaylistName(String name, Iterable<String> existing) {
  final taken = {for (final e in existing) e.toLowerCase()};
  if (!taken.contains(name.toLowerCase())) return name;
  for (var n = 2; ; n++) {
    final candidate = '$name ($n)';
    if (!taken.contains(candidate.toLowerCase())) return candidate;
  }
}

/// A file name for exporting [playlistName]: characters that file systems
/// refuse are replaced.
String m3uFileName(String playlistName) {
  final safe = playlistName
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .trim();
  return '${safe.isEmpty ? 'Playlist' : safe}.m3u';
}
