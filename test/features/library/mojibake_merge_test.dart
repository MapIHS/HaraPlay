import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/daos/library_dao.dart';
import 'package:haraplay/core/utils/text_normalize.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';
import 'package:haraplay/features/library/data/text_repair.dart';

import '../../helpers/test_database.dart';

/// [text]'s UTF-8 bytes read as Latin-1: what Android 9's scanner stored.
String latin1Mojibake(String text) => latin1.decode(utf8.encode(text));

/// The same, read as Windows-1252 (as Windows does: undefined bytes stay
/// U+0081 …).
String cp1252Mojibake(String text) {
  const cp1252 = {
    0x80: 0x20AC,
    0x82: 0x201A,
    0x83: 0x0192,
    0x84: 0x201E,
    0x85: 0x2026,
    0x86: 0x2020,
    0x87: 0x2021,
    0x88: 0x02C6,
    0x89: 0x2030,
    0x8A: 0x0160,
    0x8B: 0x2039,
    0x8C: 0x0152,
    0x8E: 0x017D,
    0x91: 0x2018,
    0x92: 0x2019,
    0x93: 0x201C,
    0x94: 0x201D,
    0x95: 0x2022,
    0x96: 0x2013,
    0x97: 0x2014,
    0x98: 0x02DC,
    0x99: 0x2122,
    0x9A: 0x0161,
    0x9B: 0x203A,
    0x9C: 0x0153,
    0x9E: 0x017E,
    0x9F: 0x0178,
  };
  return String.fromCharCodes([
    for (final b in utf8.encode(text)) cp1252[b] ?? b,
  ]);
}

const reported = '五等分の花嫁～ありがとうの花～';

void main() {
  group('isUtf8Mojibake', () {
    test('the reported song, and the Windows-1252 variant', () {
      expect(isUtf8Mojibake(latin1Mojibake(reported), reported), isTrue);
      expect(isUtf8Mojibake(cp1252Mojibake(reported), reported), isTrue);
      expect(isUtf8Mojibake(latin1Mojibake('Beyoncé'), 'Beyoncé'), isTrue);
    });

    test('never for correct text', () {
      expect(isUtf8Mojibake(reported, reported), isFalse);
      expect(isUtf8Mojibake('五等分の軌跡', reported), isFalse);
      expect(isUtf8Mojibake('Beyoncé', 'Beyonce'), isFalse);
      expect(isUtf8Mojibake('Hello', 'Hello'), isFalse);
      // Almost the mojibake, but one byte off.
      final off = latin1Mojibake(reported).replaceRange(0, 1, 'a');
      expect(isUtf8Mojibake(off, reported), isFalse);
      // A file value that is itself broken is never taken.
      expect(isUtf8Mojibake(latin1Mojibake('a�'), 'a�'), isFalse);
    });
  });

  group('isByteSwapped', () {
    // What Android 14's MediaStore made of a big-endian UTF-16 frame
    // without a BOM (seen on the emulator).
    test('the swapped reading gives way to the file text', () {
      // Exactly what the emulator's MediaStore stored (it dropped the lone
      // surrogate U+DC30 but kept U+E030).
      expect(isByteSwapped('츰ﰰ\ue030팰쌰뀰', 'ノーボムビッグ'), isTrue);
      expect(isByteSwapped('츰ﰰ팰쌰뀰', 'ノーボムビッグ'), isTrue);
      expect(isByteSwapped('䠀椀', 'Hi'), isTrue);
    });

    test('never for correct text, or when ours is the less plausible one', () {
      expect(isByteSwapped('ノーボムビッグ', 'ノーボムビッグ'), isFalse);
      expect(isByteSwapped('Hi', '䠀椀'), isFalse);
      expect(isByteSwapped('五等分の花嫁', 'Beyoncé'), isFalse);
      expect(isByteSwapped('', 'Hi'), isFalse);
    });
  });

  group('mergeTags', () {
    SongTags tags(String? title, {String? artist, String? album}) =>
        SongTags(title: title, artist: artist, album: album);

    test('takes the file text over MediaStore mojibake (title and album)', () {
      final merged = mergeTags(
        tags(
          latin1Mojibake(reported),
          artist: 'Nakanoke no Itsutsugo',
          album: latin1Mojibake('五等分の軌跡 EP'),
        ),
        tags(reported, artist: 'Nakanoke no Itsutsugo', album: '五等分の軌跡 EP'),
      );
      expect(merged.title, reported);
      expect(merged.album, '五等分の軌跡 EP');
      expect(merged.artist, 'Nakanoke no Itsutsugo');
    });

    test('keeps correct Japanese, Latin-1 and ASCII text', () {
      for (final (mediaStore, file) in [
        (reported, '五等分の花嫁'),
        ('少女A (Cover)', '少女A'),
        ('Beyoncé', 'Beyonce'),
        ('Señorita', 'Senorita (Remix)'),
        ('Hello World', 'Hello World!'),
      ]) {
        expect(mergeTags(tags(mediaStore), tags(file)).title, mediaStore);
      }
    });
  });

  group('repairFileTags', () {
    test('sends only non-ASCII text, with the file name as the hint', () async {
      final repairer = _FakeRepairer({'\u008cÜ': '五等分'});
      final results = await repairFileTags(
        repairer,
        ['/m/a/五等分.mp3', '/m/a/b.mp3', '/m/a/c.mp3'],
        const [
          FileTagsResult.read(
            SongTags(title: '\u008cÜ', artist: 'ASCII', year: 2022),
          ),
          FileTagsResult.read(SongTags(title: 'Plain')),
          FileTagsResult.failed(),
        ],
      );
      expect(repairer.sent, [('\u008cÜ', '五等分.mp3')]);
      expect(results[0].tags.title, '五等分');
      expect(results[0].tags.artist, 'ASCII');
      expect(results[0].tags.year, 2022);
      expect(results[1].tags.title, 'Plain');
      expect(results[2].failed, isTrue);
    });
  });

  test('in the library: the repaired title is searchable and sorted as '
      'Japanese; the file-name guess stays off', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final dao = db.libraryDao;
    await dao.applyScan([
      mediaSong(1, title: latin1Mojibake(reported), artist: null),
      mediaSong(2, title: 'Beyoncé'),
    ]);
    final rows = await db.select(db.songs).get();
    await dao.saveFileTags([
      (rows[0], const FileTagsResult.read(SongTags(title: reported))),
      (rows[1], const FileTagsResult.read(SongTags(title: 'Beyonce'))),
    ], readAt: DateTime(2026));
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(1))).getSingle();
    expect(song.title, reported);
    expect(song.searchText, contains(foldForSearch(reported)));
    expect(song.searchText, isNot(contains('\u0094')));
    expect(song.nameFromFilename, isFalse);
    final other = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(2))).getSingle();
    expect(other.title, 'Beyoncé', reason: 'a correct title is never altered');
  });
}

class _FakeRepairer implements TextRepairer {
  _FakeRepairer(this.fixes);

  final Map<String, String> fixes;
  final sent = <(String?, String?)>[];

  @override
  Future<List<String?>> repairAll(List<(String?, String?)> items) async {
    sent.addAll(items);
    return [for (final (text, _) in items) fixes[text] ?? text];
  }
}
