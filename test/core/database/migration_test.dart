import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/library_dao.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';

import '../../helpers/test_database.dart';

/// The songs table as schema v2–v4 created it: today's without `excluded`.
Future<String> songsTableBeforeV5() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final fresh = AppDatabase(NativeDatabase.memory());
  final create = await fresh
      .customSelect("SELECT sql FROM sqlite_master WHERE name = 'songs'")
      .map((r) => r.read<String>('sql'))
      .getSingle();
  await fresh.close();
  return create.replaceFirst(
    RegExp(
      r', "excluded" INTEGER NOT NULL DEFAULT 0 CHECK \("excluded" IN \(0, 1\)\)',
    ),
    '',
  );
}

void main() {
  test(
    'v2 → v3 adds queue_state.source_label and keeps the saved queue',
    () async {
      final songs = await songsTableBeforeV5();
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            // queue_state exactly as schema v2 created it, with a saved row.
            raw
              ..execute(songs)
              ..execute('''
              CREATE TABLE queue_state (
                id INTEGER NOT NULL CHECK (id = 1),
                song_ids TEXT NOT NULL,
                original_song_ids TEXT NULL,
                current_index INTEGER NOT NULL,
                position_ms INTEGER NOT NULL,
                shuffle INTEGER NOT NULL CHECK (shuffle IN (0, 1)),
                repeat_mode TEXT NOT NULL,
                source TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (id)
              )''')
              ..execute(
                'INSERT INTO queue_state VALUES '
                "(1, '[3,1]', NULL, 1, 4200, 0, 'all', 'album', 0)",
              )
              ..userVersion = 2;
          },
        ),
      );
      addTearDown(db.close);

      final loaded = (await db.queueStateDao.load())!;
      expect(loaded.songIds, [3, 1]);
      expect(loaded.currentIndex, 1);
      expect(loaded.position, const Duration(milliseconds: 4200));
      expect(loaded.repeat, RepeatSetting.all);
      expect(loaded.sourceLabel, isNull);

      final columns = await db
          .customSelect('PRAGMA table_info(queue_state)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(columns, contains('source_label'));
    },
  );

  test('v3 → v4 recreates song_tech_info with ReplayGain columns', () async {
    final songs = await songsTableBeforeV5();
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // song_tech_info as schema v1–v3 created it (never written).
          raw
            ..execute(songs)
            ..execute('''
              CREATE TABLE song_tech_info (
                song_id INTEGER NOT NULL,
                sample_rate INTEGER NULL,
                bit_depth INTEGER NULL,
                bitrate INTEGER NULL,
                channels INTEGER NULL,
                codec TEXT NULL,
                read_at INTEGER NOT NULL,
                PRIMARY KEY (song_id)
              )''')
            ..userVersion = 3;
        },
      ),
    );
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(song_tech_info)')
        .map((r) => r.read<String>('name'))
        .get();
    expect(
      columns,
      containsAll([
        'source_date_modified',
        'track_gain',
        'track_peak',
        'album_gain',
        'album_peak',
      ]),
    );
    expect(await db.audioInfoDao.cached(1, version: 1), isNull);
  });

  test('v4 → v5 adds songs.excluded and keeps the library', () async {
    final v4 = await songsTableBeforeV5();
    expect(v4, isNot(contains('excluded')));

    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(v4)
            ..execute(
              'INSERT INTO songs (id, title, duration_ms, size_bytes, path, '
              'folder_path, folder_name, date_added, date_modified, '
              "search_text) VALUES (1, 'A', 1000, 1, '/m/a.mp3', '/m', 'm', "
              "0, 0, 'a')",
            )
            ..userVersion = 4;
        },
      ),
    );
    addTearDown(db.close);
    final song = await db.select(db.songs).getSingle();
    expect(song.excluded, isFalse);
  });

  test('v5 → v6 clears the tag fallbacks (to read them again) and keeps '
      'the songs', () async {
    final dir = await Directory.systemTemp.createTemp('migrate');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    // A v6 database with a song and its file tags, marked as v5.
    final before = AppDatabase(NativeDatabase(file));
    await before.libraryDao.applyScan([mediaSong(1, title: 'Song')]);
    final row = (await before.select(before.songs).get()).single;
    await before.libraryDao.saveFileTags([
      (row, const FileTagsResult.read(SongTags(title: 'Song', year: 2020))),
    ], readAt: DateTime(2026));
    expect(await before.select(before.songTagFallbacks).get(), hasLength(1));
    await before.customStatement('PRAGMA user_version = 5');
    await before.close();

    final after = AppDatabase(NativeDatabase(file));
    addTearDown(after.close);
    expect(await after.select(after.songTagFallbacks).get(), isEmpty);
    expect((await after.select(after.songs).get()).single.title, 'Song');
    expect(
      (await after.libraryDao.enrichmentCandidates()).map((s) => s.id),
      contains(1),
      reason: 'read again by the next tag pass',
    );
  });
}
