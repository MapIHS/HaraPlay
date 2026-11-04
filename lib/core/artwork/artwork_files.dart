import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../database/app_database.dart';
import '../platform/media_store_channel.dart';

/// Cover art read by the app itself, for when MediaStore has none (or only
/// a small thumbnail): the picture embedded in the song's file, then an
/// image such as cover.jpg in its folder.
abstract interface class ArtworkFiles {
  /// The song's file path, or null if it isn't in the library.
  Future<String?> pathOf(int songId);

  /// The picture embedded in the file (preferring the front cover).
  Future<Uint8List?> embeddedPicture(String path);

  /// cover / folder / front .jpg, .jpeg or .png next to the file.
  Future<Uint8List?> folderImage(String path);

  /// [image] (any format) as a square JPEG of at most [sizePx].
  Future<Uint8List?> scale(Uint8List image, int sizePx);
}

/// The app's [ArtworkFiles]: paths from the library database, files read
/// in background isolates, images scaled by the platform.
class LibraryArtworkFiles implements ArtworkFiles {
  LibraryArtworkFiles(this._db, this._channel);

  final AppDatabase _db;
  final MediaStoreChannel _channel;

  /// Reading a file is slow next to a MediaStore thumbnail: a list full of
  /// songs without one would otherwise start dozens of isolates at once.
  final _slots = _Slots(2);

  @override
  Future<String?> pathOf(int songId) =>
      (_db.selectOnly(_db.songs)
            ..addColumns([_db.songs.path])
            ..where(_db.songs.id.equals(songId)))
          .map((row) => row.read(_db.songs.path))
          .getSingleOrNull();

  @override
  Future<Uint8List?> embeddedPicture(String path) =>
      _slots.run(() => Isolate.run(() => readEmbeddedPicture(path)));

  @override
  Future<Uint8List?> folderImage(String path) => _slots.run(() async {
    final folder = File(path).parent;
    final names = await folder
        .list()
        .where((e) => e is File)
        .map((e) => e.uri.pathSegments.last)
        .toList();
    final name = pickFolderImage(names);
    return name == null ? null : File('${folder.path}/$name').readAsBytes();
  });

  @override
  Future<Uint8List?> scale(Uint8List image, int sizePx) =>
      _channel.scaleArtwork(image, sizePx);
}

/// The embedded picture of [path]: the front cover, else the first one.
/// Null when there is none or the file can't be read.
Uint8List? readEmbeddedPicture(String path) {
  try {
    final pictures = readMetadata(File(path), getImage: true).pictures;
    if (pictures.isEmpty) return null;
    return pictures
        .firstWhere(
          (p) => p.pictureType == PictureType.coverFront,
          orElse: () => pictures.first,
        )
        .bytes;
  } on Object {
    // Unsupported format, truncated file or no read access.
    return null;
  }
}

/// The folder image to use among a folder's file [names]: cover, then
/// folder, then front; .jpg, .jpeg or .png; any letter case.
String? pickFolderImage(List<String> names) {
  const stems = ['cover', 'folder', 'front'];
  const extensions = ['jpg', 'jpeg', 'png'];
  for (final stem in stems) {
    for (final ext in extensions) {
      for (final name in names) {
        if (name.toLowerCase() == '$stem.$ext') return name;
      }
    }
  }
  return null;
}

/// Width and height of a JPEG, from its frame header; null if [bytes]
/// isn't a JPEG.
(int width, int height)? jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  var i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] != 0xFF) return null;
    final marker = bytes[i + 1];
    // Fill bytes before a marker.
    if (marker == 0xFF) {
      i++;
      continue;
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    // Start-of-frame markers (C0-CF, except DHT C4, JPG C8 and DAC CC).
    if (marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC) {
      final height = (bytes[i + 5] << 8) | bytes[i + 6];
      final width = (bytes[i + 7] << 8) | bytes[i + 8];
      return (width, height);
    }
    i += 2 + length;
  }
  return null;
}

/// Runs at most [_count] tasks at a time.
class _Slots {
  _Slots(this._count);

  final int _count;
  var _running = 0;
  final _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_running < _count) {
      _running++;
    } else {
      // A finishing task hands its slot straight to the next one.
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _running--;
      }
    }
  }
}
