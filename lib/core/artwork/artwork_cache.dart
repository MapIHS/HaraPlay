import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/media_source.dart';
import '../platform/media_store_channel.dart';
import 'artwork_files.dart';

/// One artwork request. [version] is the song's date_modified, so edited
/// files get fresh artwork instead of a stale cache entry.
class ArtworkRequest {
  const ArtworkRequest({
    required this.songId,
    required this.albumId,
    required this.sizePx,
    required this.version,
  });

  final int songId;
  final int? albumId;
  final int sizePx;
  final int version;

  /// Includes the size: a small cached image is never shown stretched.
  String get cacheKey => '${songId}_${sizePx}_$version';

  @override
  bool operator ==(Object other) =>
      other is ArtworkRequest &&
      other.songId == songId &&
      other.albumId == albumId &&
      other.sizePx == sizePx &&
      other.version == version;

  @override
  int get hashCode => Object.hash(songId, albumId, sizePx, version);
}

/// Disk cache for cover art. Decoded images are cached in memory by
/// Flutter's ImageCache; this class remembers the JPEG bytes across
/// launches and which songs have no artwork at all.
///
/// Where artwork comes from, in order:
/// 1. MediaStore ([MediaSource.loadArtwork]), when its image is sharp
///    enough for the requested size;
/// 2. the picture embedded in the song's file ([ArtworkFiles]);
/// 3. cover.jpg (or folder.jpg, front.jpg) in the song's folder;
/// 4. MediaStore's small image, when that's all there is.
class ArtworkCache {
  ArtworkCache(
    this._source,
    Future<Directory> Function() directory, {
    this._files,
  }) : _directory = directory;

  /// Image sizes in physical pixels; requests round up to one of these
  /// so list rows, grids and headers share cache entries. The largest
  /// cover Now Playing's artwork on big screens.
  static const sizeBuckets = [96, 192, 384, 768, 1024, 1536];

  /// MediaStore's image is used as it is when its short side is at least
  /// this share of the requested size.
  static const sharpEnough = 0.9;

  static int bucketFor(double physicalPixels) => sizeBuckets.firstWhere(
    (bucket) => bucket >= physicalPixels,
    orElse: () => sizeBuckets.last,
  );

  final MediaSource _source;
  final ArtworkFiles? _files;
  final Future<Directory> Function() _directory;
  late final Future<Directory> _dir = _directory().then((base) async {
    final dir = Directory('${base.path}/$directoryName');
    await dir.create(recursive: true);
    // 0.1.1 and older cached small MediaStore thumbnails under the same
    // keys; start over once.
    final old = Directory('${base.path}/artwork');
    if (await old.exists()) {
      try {
        await old.delete(recursive: true);
      } on FileSystemException {
        // Best-effort, like the cache itself.
      }
    }
    return dir;
  });

  /// Inside the app's cache directory.
  static const directoryName = 'covers';

  final _missing = <String>{};
  final _inFlight = <String, Future<Uint8List?>>{};

  /// JPEG bytes, or null when the song has no artwork.
  Future<Uint8List?> load(ArtworkRequest request) {
    // Files opened from other apps (negative IDs) are not in MediaStore.
    if (request.songId < 0) return Future.value();
    final key = request.cacheKey;
    if (_missing.contains(key)) return Future.value();
    // A block body: an arrow would return the removed future itself, and
    // whenComplete would then wait on the future it is completing.
    return _inFlight[key] ??= _load(request).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// The cached JPEG file for [request] (loading it first), or null when
  /// there is no artwork. Used for the playback notification.
  Future<File?> fileFor(ArtworkRequest request) async {
    if (await load(request) == null) return null;
    final file = File('${(await _dir).path}/${request.cacheKey}.jpg');
    return await file.exists() ? file : null;
  }

  /// Deletes cached files of songs that are gone, or whose file changed
  /// since ([versions]: song ID → current date_modified). Returns how many
  /// files were removed.
  Future<int> prune(Map<int, int> versions) async {
    final Directory dir;
    try {
      dir = await _dir;
    } on FileSystemException {
      return 0;
    }
    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      // "<songId>_<size>_<version>.jpg" or ".none"
      final match = RegExp(r'^(\d+)_\d+_(\d+)\.(jpg|none)$').firstMatch(name);
      if (match == null) continue;
      final songId = int.parse(match[1]!);
      if (versions[songId] == int.parse(match[2]!)) continue;
      try {
        await entity.delete();
        removed++;
      } on FileSystemException {
        // Best-effort, like the cache itself.
      }
      _missing.remove(name.substring(0, name.lastIndexOf('.')));
    }
    return removed;
  }

  Future<Uint8List?> _load(ArtworkRequest request) async {
    final key = request.cacheKey;
    final dir = await _dir;
    final file = File('${dir.path}/$key.jpg');
    final none = File('${dir.path}/$key.none');
    if (await file.exists()) return file.readAsBytes();
    if (await none.exists()) {
      _missing.add(key);
      return null;
    }

    final Uint8List? bytes;
    try {
      bytes = await _fetch(request);
    } on PlatformException {
      // e.g. access revoked: don't remember this as "no artwork".
      return null;
    }
    try {
      if (bytes == null) {
        _missing.add(key);
        await none.create();
      } else {
        await file.writeAsBytes(bytes);
      }
    } on FileSystemException {
      // The cache is best-effort.
    }
    return bytes;
  }

  Future<Uint8List?> _fetch(ArtworkRequest request) async {
    final stored = await _source.loadArtwork(
      songId: request.songId,
      albumId: request.albumId,
      sizePx: request.sizePx,
    );
    if (stored != null && _sharp(stored, request.sizePx)) return stored;
    return await _fromFiles(request) ?? stored;
  }

  /// Android 7-9 keep album art as small thumbnails (e.g. 320×180), and
  /// MediaStore misses some embedded pictures.
  static bool _sharp(Uint8List jpeg, int sizePx) {
    final size = jpegSize(jpeg);
    if (size == null) return true;
    final (width, height) = size;
    return (width < height ? width : height) >= sizePx * sharpEnough;
  }

  Future<Uint8List?> _fromFiles(ArtworkRequest request) async {
    final files = _files;
    if (files == null) return null;
    final path = await files.pathOf(request.songId);
    if (path == null) return null;
    for (final read in [files.embeddedPicture, files.folderImage]) {
      try {
        final image = await read(path);
        if (image == null) continue;
        final jpeg = await files.scale(image, request.sizePx);
        if (jpeg != null) return jpeg;
      } on FileSystemException {
        // No access to the folder (or the file is gone): try the next.
      } on PlatformException {
        // An image the platform can't decode: try the next.
      }
    }
    return null;
  }
}

final artworkCacheProvider = Provider<ArtworkCache>(
  (ref) => ArtworkCache(
    ref.watch(mediaSourceProvider),
    getApplicationCacheDirectory,
  ),
);
