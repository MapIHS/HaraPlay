import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/tags/id3.dart';
import 'package:haraplay/features/library/data/file_tag_reader.dart';

import '../../helpers/id3_fixtures.dart';

/// "五等分の花嫁" in each encoding (made with Python's codecs).
const title = '五等分の花嫁';
const utf16le = [148, 78, 73, 123, 6, 82, 110, 48, 177, 130, 193, 90];
const utf16be = [78, 148, 123, 73, 82, 6, 48, 110, 130, 177, 90, 193];
const utf8Bytes = [
  228,
  186,
  148,
  231,
  173,
  137,
  229,
  136,
  134,
  227,
  129,
  174,
  232,
  138,
  177,
  229,
  171,
  129,
];
const cp932 = [140, 220, 147, 153, 149, 170, 130, 204, 137, 212, 137, 197];

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('id3'));
  tearDown(() => temp.delete(recursive: true));

  String write(Uint8List bytes) {
    final f = File('${temp.path}/${bytes.hashCode}.mp3')
      ..writeAsBytesSync(bytes);
    return f.path;
  }

  String? titleOf(List<int> raw, int encoding, {int version = 3}) =>
      readId3Text(
        write(
          mp3WithId3(
            version: version,
            textFrames: [RawTextFrame('TIT2', encoding, raw)],
          ),
        ),
      )?.title;

  group('ID3v2 text encodings', () {
    test('UTF-16 with a BOM, either byte order', () {
      expect(titleOf([0xFF, 0xFE, ...utf16le, 0, 0], 1), title);
      expect(
        titleOf([0xFE, 0xFF, ...utf16be, 0, 0], 1),
        title,
        reason: 'audio_metadata_reader swaps these bytes',
      );
    });

    test('UTF-16 without a BOM: the plausible byte order', () {
      expect(titleOf([...utf16le, 0, 0], 1), title);
      expect(titleOf([...utf16be, 0, 0], 1), title);
      // ASCII without a BOM, big-endian.
      expect(titleOf([0, 0x48, 0, 0x69], 1), 'Hi');
    });

    test('UTF-16BE (encoding 2) and UTF-8 (encoding 3), also in ID3v2.3', () {
      expect(titleOf([...utf16be, 0, 0], 2), title);
      expect(titleOf([...utf8Bytes, 0], 3), title);
      expect(titleOf([...utf8Bytes, 0], 3, version: 4), title);
    });

    test('ISO-8859-1: kept byte for byte (the platform repairs mojibake)', () {
      expect(titleOf(latin1.encode('Beyoncé'), 0), 'Beyoncé');
      expect(titleOf([...cp932, 0], 0), latin1.decode(cp932));
    });

    test('ID3v2.2 frames and several values', () {
      final path = write(mp3WithId3(version: 2, title: 'Two'));
      expect(readId3Text(path)?.title, 'Two');
      final artists = write(
        mp3WithId3(
          version: 4,
          textFrames: [
            RawTextFrame('TPE1', 3, [
              ...utf8.encode('A'),
              0,
              ...utf8.encode('B'),
            ]),
          ],
        ),
      );
      expect(readId3Text(artists)?.artist, 'A, B');
    });
  });

  group('ID3v1', () {
    test('used where ID3v2 has nothing; ID3v2 wins otherwise', () {
      // The reported song: ID3v2.3 in UTF-16, ID3v1 with UTF-8 bytes.
      final both = write(
        mp3WithId3(
          textFrames: [
            const RawTextFrame('TIT2', 1, [0xFF, 0xFE, ...utf16le, 0, 0]),
          ],
          id3v1Fields: const Id3v1Fields(title: utf8Bytes, artist: [0x41]),
        ),
      );
      final text = readId3Text(both)!;
      expect(text.title, title);
      expect(text.artist, 'A', reason: 'not in ID3v2: from ID3v1');
    });

    test('a file with only ID3v1 still gives its tags', () {
      final full = mp3WithId3(
        id3v1Fields: const Id3v1Fields(title: cp932, artist: [0x41, 0x42]),
      );
      // Drop the ID3v2 tag.
      final path = write(Uint8List.sublistView(full, id3v2TagLength(full, 0)));
      final result = readFileTags(path);
      expect(result.failed, isFalse);
      expect(result.tags.title, latin1.decode(cp932));
      expect(result.tags.artist, 'AB');
    });
  });

  test('readFileTags prefers the correctly decoded ID3 text', () {
    final path = write(
      mp3WithId3(
        textFrames: [
          const RawTextFrame('TIT2', 1, [0xFE, 0xFF, ...utf16be, 0, 0]),
        ],
        album: 'Album',
      ),
    );
    final result = readFileTags(path);
    expect(result.tags.title, title);
    expect(result.tags.album, 'Album');
  });

  test('plain ASCII and correct text come through unchanged', () {
    expect(titleOf(ascii.encode('Hello World'), 0), 'Hello World');
    expect(titleOf([0xFF, 0xFE, ...utf16le, 0, 0], 1), title);
  });
}
