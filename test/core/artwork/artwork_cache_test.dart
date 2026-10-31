import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/artwork/artwork_cache.dart';
import 'package:haraplay/core/platform/media_source.dart';
import 'package:haraplay/core/platform/media_store_song.dart';

class _CountingSource implements MediaSource {
  _CountingSource(this.art);

  final Map<int, Uint8List?> art;
  final calls = <int>[];
  bool fail = false;

  @override
  Future<Uint8List?> loadArtwork({
    required int songId,
    int? albumId,
    required int sizePx,
  }) async {
    calls.add(songId);
    if (fail) throw PlatformException(code: 'permission_denied');
    return art[songId];
  }

  @override
  Future<List<MediaStoreSong>> querySongs() async => const [];
}

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('art'));
  tearDown(() => temp.delete(recursive: true));

  ArtworkRequest request(int songId, {int version = 1}) => ArtworkRequest(
    songId: songId,
    albumId: null,
    sizePx: 192,
    version: version,
  );

  test('loads, completes, and caches on disk', () async {
    final source = _CountingSource({
      1: Uint8List.fromList([1, 2, 3]),
    });
    final cache = ArtworkCache(source, () async => temp);

    expect(await cache.load(request(1)), [1, 2, 3]);
    expect(File('${temp.path}/artwork/1_192_1.jpg').existsSync(), isTrue);

    // A new cache (next launch) reads from disk, not the channel.
    final again = ArtworkCache(source, () async => temp);
    expect(await again.load(request(1)), [1, 2, 3]);
    expect(source.calls, [1]);
  });

  test('concurrent requests share one channel call', () async {
    final source = _CountingSource({
      1: Uint8List.fromList([9]),
    });
    final cache = ArtworkCache(source, () async => temp);

    final results = await Future.wait([
      cache.load(request(1)),
      cache.load(request(1)),
    ]);
    expect(results, [
      [9],
      [9],
    ]);
    expect(source.calls, [1]);
    // And the next call after completion works too (no stuck future).
    expect(await cache.load(request(1)), [9]);
  });

  test('remembers songs without artwork', () async {
    final source = _CountingSource({});
    final cache = ArtworkCache(source, () async => temp);

    expect(await cache.load(request(2)), isNull);
    expect(await cache.load(request(2)), isNull);
    expect(File('${temp.path}/artwork/2_192_1.none').existsSync(), isTrue);
    expect(source.calls, [2]);
  });

  test('a new version is fetched again', () async {
    final source = _CountingSource({
      3: Uint8List.fromList([1]),
    });
    final cache = ArtworkCache(source, () async => temp);
    await cache.load(request(3));
    await cache.load(request(3, version: 2));
    expect(source.calls, [3, 3]);
  });

  test('channel errors are not remembered as "no artwork"', () async {
    final source = _CountingSource({
      4: Uint8List.fromList([1]),
    })..fail = true;
    final cache = ArtworkCache(source, () async => temp);
    expect(await cache.load(request(4)), isNull);

    source.fail = false;
    expect(await cache.load(request(4)), [1]);
  });

  test('sizes round up to a bucket', () {
    expect(ArtworkCache.bucketFor(48 * 2.625), 192);
    expect(ArtworkCache.bucketFor(96), 96);
    expect(ArtworkCache.bucketFor(5000), 768);
  });

  test('prune removes covers of deleted and changed songs only', () async {
    final source = _CountingSource({
      1: Uint8List.fromList([1]),
      2: Uint8List.fromList([2]),
    });
    final cache = ArtworkCache(source, () async => temp);
    await cache.load(request(1));
    await cache.load(request(2));
    await cache.load(request(3)); // no artwork: a .none marker
    File('${temp.path}/artwork/notes.txt').writeAsStringSync('keep');

    // Song 2's file changed (version 5); song 3 was deleted.
    final removed = await cache.prune({1: 1, 2: 5});
    expect(removed, 2);
    final left = [
      for (final f in Directory('${temp.path}/artwork').listSync())
        f.uri.pathSegments.last,
    ]..sort();
    expect(left, ['1_192_1.jpg', 'notes.txt']);

    // A pruned "no artwork" entry is asked for again.
    source.calls.clear();
    await cache.load(request(3));
    expect(source.calls, [3]);
  });
}
