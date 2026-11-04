import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/artwork/artwork_cache.dart';
import 'package:haraplay/core/artwork/artwork_files.dart';
import 'package:haraplay/core/platform/media_source.dart';
import 'package:haraplay/core/platform/media_store_song.dart';

/// The start of a JPEG of [width]×[height]: SOI, an APP0 segment, then the
/// frame header, which is all [jpegSize] reads.
Uint8List jpeg(int width, int height) => Uint8List.fromList([
  0xFF, 0xD8, // SOI
  0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, 2 bytes of payload
  0xFF, 0xC0, 0x00, 0x11, 0x08, // SOF0, precision 8
  height >> 8, height & 0xFF, width >> 8, width & 0xFF,
  0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0, // components
]);

class _Store implements MediaSource {
  _Store([this.image]);

  final Uint8List? image;
  final sizes = <int>[];

  /// Android 9 throws for some albums without art (the `<unknown>` album).
  bool fail = false;

  @override
  Future<Uint8List?> loadArtwork({
    required int songId,
    int? albumId,
    required int sizePx,
  }) async {
    sizes.add(sizePx);
    if (fail) {
      throw PlatformException(
        code: 'media_store_error',
        details: 'java.lang.IllegalStateException',
      );
    }
    return image;
  }

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<List<MediaStoreSong>> querySongs() async => const [];
}

class _Files implements ArtworkFiles {
  _Files({
    this.embedded,
    this.folder,
    this.folderError = false,
    this.fileError = false,
  });

  final Uint8List? embedded;
  final Uint8List? folder;
  final bool folderError;

  /// The song file can't be read right now.
  bool fileError;
  final calls = <String>[];

  @override
  Future<String?> pathOf(int songId) async {
    calls.add('path $songId');
    return '/music/a/$songId.mp3';
  }

  @override
  Future<Uint8List?> embeddedPicture(String path) async {
    calls.add('embedded');
    if (fileError) throw FileSystemException('busy', path);
    return embedded;
  }

  @override
  Future<Uint8List?> folderImage(String path) async {
    calls.add('folder');
    if (folderError) throw const FileSystemException('denied');
    return folder;
  }

  @override
  Future<Uint8List?> scale(Uint8List image, int sizePx) async {
    calls.add('scale $sizePx');
    // Marks which image was scaled, at which size.
    return Uint8List.fromList([...image.take(1), sizePx ~/ 96]);
  }
}

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('art'));
  tearDown(() => temp.delete(recursive: true));

  ArtworkRequest request(int sizePx, {int songId = 1}) =>
      ArtworkRequest(songId: songId, albumId: 7, sizePx: sizePx, version: 1);

  final embedded = Uint8List.fromList([0xE0]);
  final folder = Uint8List.fromList([0xF0]);

  group('fallback order', () {
    test('a sharp MediaStore image is used; the file is never read', () async {
      final store = _Store(jpeg(800, 800));
      final files = _Files(embedded: embedded, folder: folder);
      final cache = ArtworkCache(store, () async => temp, files: files);
      expect(await cache.load(request(768)), jpeg(800, 800));
      expect(files.calls, isEmpty);
    });

    test('no MediaStore image: the embedded picture, at the requested '
        'size', () async {
      final files = _Files(embedded: embedded, folder: folder);
      final cache = ArtworkCache(_Store(), () async => temp, files: files);
      expect(await cache.load(request(384)), [0xE0, 4]);
      expect(files.calls, ['path 1', 'embedded', 'scale 384']);
    });

    test('no embedded picture: the folder image', () async {
      final files = _Files(folder: folder);
      final cache = ArtworkCache(_Store(), () async => temp, files: files);
      expect(await cache.load(request(192)), [0xF0, 2]);
      expect(files.calls, ['path 1', 'embedded', 'folder', 'scale 192']);
    });

    test('a small MediaStore thumbnail (Android 9: 320×180) gives way to '
        'the file', () async {
      final files = _Files(embedded: embedded);
      final cache = ArtworkCache(
        _Store(jpeg(320, 180)),
        () async => temp,
        files: files,
      );
      expect(await cache.load(request(768)), [0xE0, 8]);
    });

    test('the small thumbnail still beats nothing', () async {
      final cache = ArtworkCache(
        _Store(jpeg(320, 180)),
        () async => temp,
        files: _Files(folderError: true),
      );
      expect(await cache.load(request(768)), jpeg(320, 180));
    });

    test('nothing anywhere is remembered as "no artwork"', () async {
      final files = _Files();
      final cache = ArtworkCache(_Store(), () async => temp, files: files);
      expect(await cache.load(request(192)), isNull);
      expect(await cache.load(request(192)), isNull);
      expect(File('${temp.path}/covers/1_192_1.none').existsSync(), isTrue);
      expect(files.calls.where((c) => c == 'embedded'), hasLength(1));
    });

    test('an image the platform can\'t decode moves on to the next '
        'source', () async {
      final files = _ThrowingScale(embedded: embedded, folder: folder);
      final cache = ArtworkCache(_Store(), () async => temp, files: files);
      expect(await cache.load(request(192)), [0xF0, 2]);
    });
  });

  group('cache keys', () {
    test('every size is its own entry: a small cached image is never '
        'reused for a bigger one', () async {
      final store = _Store();
      final files = _Files(embedded: embedded);
      final cache = ArtworkCache(store, () async => temp, files: files);
      expect(await cache.load(request(96)), [0xE0, 1]);
      expect(await cache.load(request(768)), [0xE0, 8]);
      expect(store.sizes, [96, 768]);
      final names = [
        for (final f in Directory('${temp.path}/covers').listSync())
          f.uri.pathSegments.last,
      ]..sort();
      expect(names, ['1_768_1.jpg', '1_96_1.jpg']);
      expect(request(96).cacheKey, isNot(request(768).cacheKey));
    });

    test('images from the file are cached like MediaStore ones', () async {
      final files = _Files(embedded: embedded);
      await ArtworkCache(
        _Store(),
        () async => temp,
        files: files,
      ).load(request(384));
      files.calls.clear();
      // Next launch: from disk.
      final again = ArtworkCache(_Store(), () async => temp, files: files);
      expect(await again.load(request(384)), [0xE0, 4]);
      expect(files.calls, isEmpty);
    });
  });

  test('jpegSize reads the frame header', () {
    expect(jpegSize(jpeg(320, 180)), (320, 180));
    expect(jpegSize(jpeg(1500, 1500)), (1500, 1500));
    expect(jpegSize(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])), isNull);
  });

  test('pickFolderImage: cover, folder, front, album, albumart, then '
      'Windows Media Player\'s files; any case', () {
    expect(
      pickFolderImage(['Front.jpg', 'Folder.JPG', 'cover.png']),
      'cover.png',
    );
    expect(pickFolderImage(['front.jpeg', 'Folder.jpg']), 'Folder.jpg');
    expect(pickFolderImage(['song.mp3', 'FRONT.PNG']), 'FRONT.PNG');
    expect(pickFolderImage(['Cover.JPG']), 'Cover.JPG');
    expect(pickFolderImage(['album.jpg', 'AlbumArt.jpg']), 'album.jpg');
    expect(
      pickFolderImage([
        'AlbumArtSmall.jpg',
        'AlbumArt_{4D5A1F2E-0000-1111-2222-333344445555}_Large.jpg',
      ]),
      'AlbumArt_{4D5A1F2E-0000-1111-2222-333344445555}_Large.jpg',
    );
    expect(pickFolderImage(['AlbumArtSmall.jpg']), 'AlbumArtSmall.jpg');
    expect(pickFolderImage(['cover.webp']), 'cover.webp');
    expect(pickFolderImage(['Folder.BMP']), 'Folder.BMP');
    expect(
      pickFolderImage(['song.mp3', 'back.jpg', 'cover.gif', 'photo.jpg']),
      isNull,
    );
  });

  group('MediaStore errors and unreliable misses', () {
    test('MediaStore throws (Android 9, "<unknown>" album): the embedded '
        'picture is still used and remembered', () async {
      final store = _Store()..fail = true;
      final files = _Files(embedded: embedded);
      final cache = ArtworkCache(store, () async => temp, files: files);
      expect(await cache.load(request(384)), [0xE0, 4]);
      expect(File('${temp.path}/covers/1_384_1.jpg').existsSync(), isTrue);
    });

    test('MediaStore throws and the file has nothing: not remembered as '
        '"no artwork"; asked again after a minute', () async {
      var now = DateTime(2026, 11, 5);
      final store = _Store()..fail = true;
      final files = _Files();
      final cache = ArtworkCache(
        store,
        () async => temp,
        files: files,
        now: () => now,
      );
      expect(await cache.load(request(192)), isNull);
      expect(File('${temp.path}/covers/1_192_1.none').existsSync(), isFalse);
      expect(await cache.load(request(192)), isNull);
      expect(store.sizes, hasLength(1), reason: 'not on every rebuild');
      now = now.add(ArtworkCache.retryUncertainAfter);
      await cache.load(request(192));
      expect(store.sizes, hasLength(2));
    });

    test('an unreadable song file is not remembered as "no artwork"', () async {
      var now = DateTime(2026, 11, 5);
      final files = _Files(embedded: embedded, fileError: true);
      final cache = ArtworkCache(
        _Store(),
        () async => temp,
        files: files,
        now: () => now,
      );
      expect(await cache.load(request(192)), isNull);
      expect(File('${temp.path}/covers/1_192_1.none').existsSync(), isFalse);
      // The download finished.
      files.fileError = false;
      now = now.add(ArtworkCache.retryUncertainAfter);
      expect(await cache.load(request(192)), [0xE0, 2]);
    });

    test(
      'a folder that can\'t be listed (Android 13+) is a plain miss',
      () async {
        final cache = ArtworkCache(
          _Store(),
          () async => temp,
          files: _Files(folderError: true),
        );
        expect(await cache.load(request(192)), isNull);
        expect(File('${temp.path}/covers/1_192_1.none').existsSync(), isTrue);
      },
    );
  });

  group('"no artwork" markers', () {
    late DateTime now;
    late _Files files;
    late ArtworkCache cache;
    File marker() => File('${temp.path}/covers/1_192_1.none');

    setUp(() {
      now = DateTime(2026, 11, 5);
      files = _Files();
      cache = ArtworkCache(
        _Store(),
        () async => temp,
        files: files,
        now: () => now,
      );
    });

    Future<void> seed(String contents, DateTime written) async {
      Directory('${temp.path}/covers').createSync(recursive: true);
      marker()
        ..writeAsStringSync(contents)
        ..setLastModifiedSync(written);
    }

    test('a current marker is trusted', () async {
      await seed(ArtworkCache.noArtworkGeneration, now);
      expect(await cache.load(request(192)), isNull);
      expect(files.calls, isEmpty);
    });

    test("0.1.2's markers (empty) are looked at again", () async {
      await seed('', now);
      expect(await cache.load(request(192)), isNull);
      expect(files.calls, contains('embedded'));
      expect(marker().readAsStringSync(), ArtworkCache.noArtworkGeneration);
    });

    test('a marker older than a week is looked at again, and a cover found '
        'then replaces it', () async {
      await seed(
        ArtworkCache.noArtworkGeneration,
        now.subtract(ArtworkCache.noArtworkFor),
      );
      final found = ArtworkCache(
        _Store(),
        () async => temp,
        files: _Files(folder: folder),
        now: () => now,
      );
      expect(await found.load(request(192)), [0xF0, 2]);
      expect(marker().existsSync(), isFalse);
    });
  });
}

class _ThrowingScale extends _Files {
  _ThrowingScale({super.embedded, super.folder});

  /// The embedded picture is broken.
  @override
  Future<Uint8List?> scale(Uint8List image, int sizePx) async {
    if (image.first == 0xE0) throw PlatformException(code: 'not_an_image');
    return super.scale(image, sizePx);
  }
}
