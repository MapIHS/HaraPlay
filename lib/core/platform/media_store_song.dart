/// One audio file as reported by Android's MediaStore, normalised:
/// MediaStore's `<unknown>` placeholders and blank strings become null, the
/// combined disc/track number is split, and times are UTC.
class MediaStoreSong {
  const MediaStoreSong({
    required this.id,
    required this.title,
    required this.path,
    required this.folderPath,
    required this.folderName,
    required this.duration,
    required this.sizeBytes,
    required this.dateAdded,
    required this.dateModified,
    this.artist,
    this.album,
    this.albumArtist,
    this.albumId,
    this.artistId,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.mimeType,
  });

  /// Parses one row from the `querySongs` channel call. Returns null for rows
  /// without an ID or a file path, which cannot be played or re-linked.
  static MediaStoreSong? tryParse(Map<Object?, Object?> map) =>
      _parse((key) => map[key]);

  /// Decodes the column-wise `querySongs` reply (see `MediaStoreQueries.kt`):
  /// packed number columns, and repeated text as indices into `strings`.
  static List<MediaStoreSong> fromColumns(Map<Object?, Object?> reply) {
    final count = _int(reply['count']) ?? 0;
    if (count == 0) return const [];
    final noValue = _int(reply['noValue']);
    final strings = (reply['strings']! as List<Object?>).cast<String>();
    final longs = (reply['longs']! as Map<Object?, Object?>)
        .cast<String, List<int>>();
    final shared = (reply['shared']! as Map<Object?, Object?>)
        .cast<String, List<int>>();
    final folders = reply['folders']! as List<int>;
    final titles = reply['titles']! as List<Object?>;
    final fileNames = reply['fileNames']! as List<Object?>;

    String? sharedText(int index) => index < 0 ? null : strings[index];
    final songs = <MediaStoreSong>[];
    for (var row = 0; row < count; row++) {
      Object? value(String key) {
        switch (key) {
          case 'title':
            return titles[row];
          case 'path':
            final name = fileNames[row] as String?;
            final folder = sharedText(folders[row]);
            return name == null || folder == null ? name : '$folder/$name';
        }
        final packed = longs[key];
        if (packed != null) {
          final v = packed[row];
          return v == noValue ? null : v;
        }
        final ref = shared[key];
        return ref == null ? null : sharedText(ref[row]);
      }

      final song = _parse(value);
      if (song != null) songs.add(song);
    }
    return songs;
  }

  static MediaStoreSong? _parse(Object? Function(String key) map) {
    final id = _int(map('id'));
    final path = _text(map('path'));
    if (id == null || path == null) return null;

    final slash = path.lastIndexOf('/');
    final folderPath = slash > 0 ? path.substring(0, slash) : '/';
    final fileName = path.substring(slash + 1);
    final folderName = folderPath.substring(folderPath.lastIndexOf('/') + 1);

    // MediaStore stores the disc in the thousands: 2005 = disc 2, track 5.
    final rawTrack = _int(map('track')) ?? 0;
    final disc = rawTrack ~/ 1000;
    final track = rawTrack % 1000;

    return MediaStoreSong(
      id: id,
      title: _text(map('title')) ?? _stripExtension(fileName),
      artist: _text(map('artist')),
      album: _text(map('album')),
      albumArtist: _text(map('albumArtist')),
      albumId: _int(map('albumId')),
      artistId: _int(map('artistId')),
      genre: _text(map('genre')),
      trackNumber: track > 0 ? track : null,
      discNumber: disc > 0 ? disc : null,
      year: _positive(map('year')),
      duration: Duration(milliseconds: _int(map('durationMs')) ?? 0),
      sizeBytes: _int(map('sizeBytes')) ?? 0,
      mimeType: _text(map('mimeType')),
      path: path,
      folderPath: folderPath,
      folderName: folderName.isEmpty ? folderPath : folderName,
      dateAdded: _epochSeconds(map('dateAddedSec')),
      dateModified: _epochSeconds(map('dateModifiedSec')),
    );
  }

  final int id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? albumId;
  final int? artistId;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final Duration duration;
  final int sizeBytes;
  final String? mimeType;
  final String path;
  final String folderPath;
  final String folderName;
  final DateTime dateAdded;
  final DateTime dateModified;

  MediaStoreSong withGenre(String? genre) => MediaStoreSong(
    id: id,
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    albumId: albumId,
    artistId: artistId,
    genre: genre,
    trackNumber: trackNumber,
    discNumber: discNumber,
    year: year,
    duration: duration,
    sizeBytes: sizeBytes,
    mimeType: mimeType,
    path: path,
    folderPath: folderPath,
    folderName: folderName,
    dateAdded: dateAdded,
    dateModified: dateModified,
  );

  @override
  String toString() => 'MediaStoreSong($id, $title, $path)';
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '<unknown>') return null;
  return trimmed;
}

int? _int(Object? value) => value is num ? value.toInt() : null;

int? _positive(Object? value) {
  final number = _int(value);
  return number != null && number > 0 ? number : null;
}

DateTime _epochSeconds(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch((_int(value) ?? 0) * 1000, isUtc: true);

String _stripExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.substring(0, dot) : fileName;
}
