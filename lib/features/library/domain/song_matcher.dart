/// The phone's own storage has several names for the same place;
/// MediaStore (and the library) use `/storage/emulated/0`.
String normalizeStoragePath(String path) {
  for (final alias in const [
    '/sdcard/',
    '/mnt/sdcard/',
    '/storage/self/primary/',
    '/mnt/user/0/primary/',
  ]) {
    if (path.startsWith(alias)) {
      return '/storage/emulated/0/${path.substring(alias.length)}';
    }
  }
  return path;
}

/// A library song as the matcher needs it.
typedef MatchableSong = ({int id, String path, int sizeBytes});

/// Finds library songs for paths remembered elsewhere (a backup, another
/// app's link): by path (storage aliases normalised, then ignoring case,
/// as shared storage does), then by file name + exact size, which finds a
/// file that moved folders or a library on another phone.
class SongMatcher {
  SongMatcher(Iterable<MatchableSong> songs) {
    for (final song in songs) {
      _byPath.putIfAbsent(song.path, () => song);
      _byLowerPath.putIfAbsent(song.path.toLowerCase(), () => song);
      if (song.sizeBytes > 0) {
        _byNameAndSize.putIfAbsent((
          _fileName(song.path).toLowerCase(),
          song.sizeBytes,
        ), () => song);
      }
    }
  }

  final _byPath = <String, MatchableSong>{};
  final _byLowerPath = <String, MatchableSong>{};
  final _byNameAndSize = <(String, int), MatchableSong>{};

  MatchableSong? find(String path, {int sizeBytes = 0, String? fileName}) {
    final normal = normalizeStoragePath(path);
    final byPath = _byPath[normal] ?? _byLowerPath[normal.toLowerCase()];
    if (byPath != null) return byPath;
    final name = fileName ?? _fileName(path);
    if (sizeBytes <= 0 || name.isEmpty) return null;
    return _byNameAndSize[(name.toLowerCase(), sizeBytes)];
  }

  static String _fileName(String path) => path.split('/').last;
}
