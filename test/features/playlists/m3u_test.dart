import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/playlists/data/m3u_service.dart';
import 'package:haraplay/features/playlists/domain/m3u.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_database.dart';

const _music = '/storage/emulated/0/Music';

void main() {
  group('writing', () {
    test('header, EXTINF and full paths', () {
      expect(
        writeM3u([
          (
            path: '$_music/a.mp3',
            title: 'Night Drive',
            artist: 'Mono Lisa',
            duration: const Duration(seconds: 215, milliseconds: 600),
          ),
          (
            path: '$_music/b.flac',
            title: 'Two\nLines',
            artist: null,
            duration: const Duration(seconds: 61),
          ),
        ]),
        '#EXTM3U\n'
        '#EXTINF:215,Mono Lisa - Night Drive\n'
        '$_music/a.mp3\n'
        '#EXTINF:61,Two Lines\n'
        '$_music/b.flac\n',
      );
    });

    test('file names', () {
      expect(m3uFileName('Road Trip'), 'Road Trip.m3u');
      expect(m3uFileName('AC/DC: best?'), 'AC_DC_ best_.m3u');
      expect(playlistNameFromFile('Road Trip.M3U8'), 'Road Trip');
      expect(playlistNameFromFile(null), 'Imported playlist');
      expect(uniquePlaylistName('Mix', ['mix', 'Mix (2)']), 'Mix (3)');
    });
  });

  group('reading', () {
    test('skips comments and blank lines; handles CRLF, BOM and file URIs', () {
      expect(
        parseM3u(
          '\uFEFF#EXTM3U\r\n#EXTINF:10,A - B\r\n'
          'music/a.mp3\r\n\r\n# note\r\n'
          'file:///storage/emulated/0/Music/My%20Song.mp3\n'
          'C:\\Users\\me\\Music\\c.mp3\n'
          'https://radio.example/stream\n',
        ),
        [
          'music/a.mp3',
          '/storage/emulated/0/Music/My Song.mp3',
          'C:\\Users\\me\\Music\\c.mp3',
          'https://radio.example/stream',
        ],
      );
    });

    final library = {
      1: '$_music/Rock/a.mp3',
      2: '$_music/Pop/a.mp3',
      3: '$_music/Pop/b.mp3',
      4: '/storage/1A2B-3C4D/Jazz/c.flac',
    };

    test('matches full, relative, case-different and moved paths', () {
      final match = matchM3u(
        [
          '$_music/Pop/b.mp3', // full path
          '../Rock/a.mp3', // relative to the playlist's folder
          '$_music/pop/B.MP3', // case differs
          'D:\\Old PC\\Jazz\\c.flac', // made on a computer
          'Pop/a.mp3', // same name in two folders: Pop wins
          'a.mp3', // ambiguous: two songs named a.mp3
          'https://radio.example/stream',
          '$_music/gone.mp3',
        ],
        library,
        playlistPath: '$_music/Lists/mix.m3u',
      );
      expect(match.songIds, [3, 1, 3, 4, 2]);
      expect(match.missing, [
        'a.mp3',
        'https://radio.example/stream',
        '$_music/gone.mp3',
      ]);
    });

    test('relative paths without a known playlist folder fall back to '
        'file names', () {
      final match = matchM3u(['Jazz/c.flac'], library);
      expect(match.songIds, [4]);
    });
  });

  group('M3uService', () {
    late AppDatabase db;
    late FakeDocumentFiles files;
    late M3uService service;

    setUp(() async {
      db = createTestDatabase();
      await db.libraryDao.applyScan([
        mediaSong(1, path: '$_music/a.mp3', title: 'Alpha', artist: 'X'),
        mediaSong(2, path: '$_music/b.mp3', title: 'Beta'),
      ]);
      files = FakeDocumentFiles();
      service = M3uService(
        db.playlistsDao,
        files,
        clock: () => DateTime(2026, 11),
      );
    });
    tearDown(() => db.close());

    test('exports a playlist in order, duplicates included', () async {
      final id = await db.playlistsDao.create('Road Trip', at: DateTime(2026));
      await db.playlistsDao.addSongs(id, [2, 1, 2], at: DateTime(2026));
      final playlist = (await db.playlistsDao.watchPlaylists().first).single;

      expect(await service.export(playlist), 'Road Trip.m3u');
      expect(files.savedText, startsWith('#EXTM3U\n#EXTINF:180,Beta\n'));
      expect(parseM3u(files.savedText!), [
        '$_music/b.mp3',
        '$_music/a.mp3',
        '$_music/b.mp3',
      ]);

      files.cancelSave = true;
      expect(await service.export(playlist), isNull);
    });

    test('an exported playlist imports back as a copy', () async {
      final id = await db.playlistsDao.create('Road Trip', at: DateTime(2026));
      await db.playlistsDao.addSongs(id, [2, 1], at: DateTime(2026));
      await service.export(
        (await db.playlistsDao.watchPlaylists().first).single,
      );

      files.toOpen = (
        name: 'Road Trip.m3u',
        path: null,
        bytes: Uint8List.fromList(
          utf8.encode('${files.savedText!}$_music/missing.mp3\n'),
        ),
      );
      final result = (await service.import())!;
      expect(result.name, 'Road Trip (2)');
      expect((result.found, result.missing), (2, 1));
      expect(
        describeImport(result),
        "Imported 2 of 3 songs; 1 isn't on this phone.",
      );
      final entries = await db.playlistsDao
          .watchEntries(result.playlistId!)
          .first;
      expect(entries.map((e) => e.song.id), [2, 1]);
    });

    test('nothing found: no playlist is made; cancelled: nothing', () async {
      files.toOpen = (
        name: 'old.m3u',
        path: null,
        bytes: Uint8List.fromList(utf8.encode('/sdcard/x.mp3\n')),
      );
      final result = (await service.import())!;
      expect(result.playlistId, isNull);
      expect(
        describeImport(result),
        "The song in this file isn't on this phone.",
      );
      expect(await db.playlistsDao.watchPlaylists().first, isEmpty);

      files.toOpen = null;
      expect(await service.import(), isNull);
    });
  });
}
