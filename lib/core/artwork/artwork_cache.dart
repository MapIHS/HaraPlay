import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/media_source.dart';
import '../platform/media_store_channel.dart';

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

/// Disk cache in front of [MediaSource.loadArtwork]. Decoded images are
/// cached in memory by Flutter's ImageCache; this class remembers the JPEG
/// bytes across launches and which songs have no artwork at all.
class ArtworkCache {
  ArtworkCache(this._source, Future<Directory> Function() directory)
    : _directory = directory;

  /// Thumbnail sizes in physical pixels; requests round up to one of these
  /// so list rows, grids and headers share cache entries.
  static const sizeBuckets = [96, 192, 384, 768];

  static int bucketFor(double physicalPixels) => sizeBuckets.firstWhere(
    (bucket) => bucket >= physicalPixels,
    orElse: () => sizeBuckets.last,
  );

  final MediaSource _source;
  final Future<Directory> Function() _directory;
  late final Future<Directory> _dir = _directory().then((base) async {
    final dir = Directory('${base.path}/artwork');
    await dir.create(recursive: true);
    return dir;
  });

  final _missing = <String>{};
  final _inFlight = <String, Future<Uint8List?>>{};

  /// JPEG bytes, or null when the song has no artwork.
  Future<Uint8List?> load(ArtworkRequest request) {
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
      bytes = await _source.loadArtwork(
        songId: request.songId,
        albumId: request.albumId,
        sizePx: request.sizePx,
      );
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
}

final artworkCacheProvider = Provider<ArtworkCache>(
  (ref) => ArtworkCache(
    ref.watch(mediaSourceProvider),
    getApplicationCacheDirectory,
  ),
);
