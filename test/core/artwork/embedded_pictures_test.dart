import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/artwork/artwork_files.dart';
import 'package:haraplay/core/artwork/embedded_pictures.dart';
import 'package:haraplay/core/platform/media_store_channel.dart';

import '../../helpers/id3_fixtures.dart';
import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('pics'));
  tearDown(() => temp.delete(recursive: true));

  String write(Uint8List bytes, [String name = 'song.mp3']) {
    final file = File('${temp.path}/$name')..writeAsBytesSync(bytes);
    return file.path;
  }

  final wide = fakeJpeg(1280, 720);
  final square = fakeJpeg(600, 600, fill: 1);

  group('readEmbeddedPicture finds the cover in', () {
    test('ID3v2.3 without an album tag, plus ID3v1 (the two songs from '
        'the report)', () {
      final path = write(mp3WithId3(pictures: [Id3Picture(wide)], id3v1: true));
      expect(readEmbeddedPicture(path), wide);
    });

    test('ID3v2.4', () {
      final path = write(
        mp3WithId3(version: 4, pictures: [Id3Picture(square)]),
      );
      expect(readEmbeddedPicture(path), square);
    });

    test('ID3v2.2 (PIC frames; audio_metadata_reader skips them)', () {
      final path = write(
        mp3WithId3(version: 2, pictures: [Id3Picture(square)]),
      );
      expect(readEmbeddedPicture(path), square);
    });

    test('unsynchronised ID3v2.3 and 2.4 tags', () {
      for (final version in [3, 4]) {
        final path = write(
          mp3WithId3(
            version: version,
            unsynchronised: true,
            pictures: [Id3Picture(square)],
          ),
        );
        expect(readEmbeddedPicture(path), square, reason: 'v2.$version');
      }
    });

    test('a UTF-16 description, a nonstandard or empty MIME type, PNG', () {
      for (final picture in [
        Id3Picture(square, utf16: true, description: 'Front'),
        Id3Picture(square, mime: 'image/jpg'),
        Id3Picture(square, mime: ''),
        Id3Picture(fakePng(600, 600), mime: 'image/png'),
      ]) {
        final path = write(mp3WithId3(pictures: [picture]));
        expect(readEmbeddedPicture(path), picture.bytes);
      }
    });

    test('an APEv2 tag at the end', () {
      final path = write(withTrailer(mp3WithId3(), apeCoverTag(square)));
      expect(readEmbeddedPicture(path), square);
    });
  });

  group('choosing among pictures', () {
    test('the front cover, wherever it is', () {
      final path = write(
        mp3WithId3(pictures: [Id3Picture(wide, type: 4), Id3Picture(square)]),
      );
      expect(readEmbeddedPicture(path), square);
    });

    test('then "other", then anything but a file icon', () {
      final icon = fakeJpeg(32, 32);
      expect(
        readEmbeddedPicture(
          write(
            mp3WithId3(
              pictures: [Id3Picture(icon, type: 1), Id3Picture(wide, type: 0)],
            ),
          ),
        ),
        wide,
      );
      expect(
        readEmbeddedPicture(
          write(
            mp3WithId3(
              pictures: [Id3Picture(icon, type: 1), Id3Picture(wide, type: 4)],
            ),
            'b.mp3',
          ),
        ),
        wide,
      );
    });

    test('a link ("-->") is not an image', () {
      expect(
        choosePicture([
          FoundPicture(
            Uint8List.fromList(List.filled(40, 65)),
            type: 3,
            mime: '-->',
          ),
        ]),
        isNull,
      );
    });
  });

  group('no cover', () {
    test('no picture at all', () {
      expect(readEmbeddedPicture(write(mp3WithId3())), isNull);
    });

    test('a damaged tag is a miss, not a crash', () {
      final whole = mp3WithId3(pictures: [Id3Picture(square)]);
      // Cut in the middle of the picture frame.
      final path = write(Uint8List.sublistView(whole, 0, 40));
      expect(() => readEmbeddedPicture(path), returnsNormally);
    });

    test('an unreadable file throws, so it is not taken for "no cover"', () {
      expect(
        () => readEmbeddedPicture('${temp.path}/missing.mp3'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('...also across the background isolate', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final files = LibraryArtworkFiles(db, MediaStoreChannel());
      await expectLater(
        files.embeddedPicture('${temp.path}/missing.mp3'),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await files.embeddedPicture(
          write(mp3WithId3(pictures: [Id3Picture(wide)])),
        ),
        wide,
      );
    });
  });
}
