import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/library_dao.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LibraryDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = db.libraryDao;
  });
  tearDown(() => db.close());

  Future<List<SongRow>> allSongs() => (db.select(
    db.songs,
  )..orderBy([(s) => OrderingTerm(expression: s.id)])).get();

  Future<void> like(int songId) => db
      .into(db.favorites)
      .insert(
        FavoritesCompanion.insert(
          songId: Value(songId),
          songPath: 'p',
          addedAt: 0,
        ),
      );

  Future<int> playlistWith(List<int> songIds) async {
    final id = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(name: 'Mix', createdAt: 0, updatedAt: 0),
        );
    for (final (i, songId) in songIds.indexed) {
      await db
          .into(db.playlistEntries)
          .insert(
            PlaylistEntriesCompanion.insert(
              playlistId: id,
              songId: songId,
              songPath: 'p',
              position: i,
              addedAt: 0,
            ),
          );
    }
    return id;
  }

  Future<void> played(int songId) => db
      .into(db.playEvents)
      .insert(
        PlayEventsCompanion.insert(
          songId: Value(songId),
          songPath: 'p',
          title: 'Song $songId',
          startedAt: 0,
          listenedMs: 1000,
          durationMs: 180000,
          completed: true,
          source: PlaySource.songs,
        ),
      );

  test('first sync inserts every song with search text', () async {
    final result = await dao.applyScan([
      mediaSong(1, title: 'Señorita Café', artist: 'Beyoncé'),
      mediaSong(2),
    ]);

    expect(result.added, 2);
    expect(result.total, 2);
    final songs = await allSongs();
    expect(songs.first.searchText, 'senorita cafe beyonce');
    expect(songs.first.folderName, 'Music');
  });

  test('a second identical sync writes nothing', () async {
    await dao.applyScan([mediaSong(1), mediaSong(2)]);
    final result = await dao.applyScan([mediaSong(1), mediaSong(2)]);
    expect(result.changedAnything, isFalse);
  });

  test('changed tags count as updates', () async {
    await dao.applyScan([mediaSong(1)]);
    final result = await dao.applyScan([
      mediaSong(1, title: 'Renamed', modifiedSec: 1700000100),
    ]);
    expect(result.updated, 1);
    expect((await allSongs()).single.title, 'Renamed');
  });

  test('a tag removed from the file is cleared', () async {
    await dao.applyScan([mediaSong(1, artist: 'Kai Tone', year: 2015)]);
    await dao.applyScan([mediaSong(1, modifiedSec: 1700000100)]);

    final song = (await allSongs()).single;
    expect(song.artist, isNull);
    expect(song.year, isNull);
  });

  test('deleted files are removed, with cascades', () async {
    await dao.applyScan([mediaSong(1), mediaSong(2)]);
    await like(1);
    final playlist = await playlistWith([1, 2, 1]);
    await played(1);

    final result = await dao.applyScan([mediaSong(2)]);

    expect(result.removed, 1);
    expect(await db.select(db.favorites).get(), isEmpty);
    final entries = await (db.select(
      db.playlistEntries,
    )..where((e) => e.playlistId.equals(playlist))).get();
    expect(entries.map((e) => e.songId), [2]);
    // History keeps its snapshot but loses the link.
    final event = await db.select(db.playEvents).getSingle();
    expect(event.songId, isNull);
    expect(event.title, 'Song 1');
  });

  test('a new MediaStore ID for the same path re-keys everything', () async {
    await dao.applyScan([mediaSong(1, path: '/m/a.mp3'), mediaSong(2)]);
    await like(1);
    await playlistWith([1]);
    await played(1);

    final result = await dao.applyScan([
      mediaSong(41, path: '/m/a.mp3'),
      mediaSong(2),
    ]);

    expect(result.rekeyed, 1);
    expect(result.added, 0);
    expect(result.removed, 0);
    expect((await allSongs()).map((s) => s.id), [2, 41]);
    expect((await db.select(db.favorites).getSingle()).songId, 41);
    expect((await db.select(db.playlistEntries).getSingle()).songId, 41);
    expect((await db.select(db.playEvents).getSingle()).songId, 41);
  });

  test('two songs swapping IDs keep their own favorites', () async {
    await dao.applyScan([
      mediaSong(1, path: '/m/a.mp3'),
      mediaSong(2, path: '/m/b.mp3'),
    ]);
    await like(1); // a.mp3

    final result = await dao.applyScan([
      mediaSong(2, path: '/m/a.mp3'),
      mediaSong(1, path: '/m/b.mp3'),
    ]);

    expect(result.rekeyed, 2);
    final favorite = await db.select(db.favorites).getSingle();
    final liked = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(favorite.songId))).getSingle();
    expect(liked.path, '/m/a.mp3');
  });

  test('a renamed file that keeps its ID is updated in place', () async {
    await dao.applyScan([mediaSong(1, path: '/m/old.mp3')]);
    await like(1);

    final result = await dao.applyScan([mediaSong(1, path: '/m/new.mp3')]);

    expect(result.updated, 1);
    expect(result.removed, 0);
    expect((await allSongs()).single.path, '/m/new.mp3');
    expect(await db.select(db.favorites).get(), hasLength(1));
  });

  test('an ID reused for a different, already-known file', () async {
    // a.mp3 is deleted; MediaStore gives its old ID to b.mp3.
    await dao.applyScan([
      mediaSong(1, path: '/m/a.mp3'),
      mediaSong(2, path: '/m/b.mp3'),
    ]);
    await like(1);
    await like(2);

    final result = await dao.applyScan([mediaSong(1, path: '/m/b.mp3')]);

    expect(result.removed, 1);
    expect(result.rekeyed, 1);
    final songs = await allSongs();
    expect(songs.single.id, 1);
    expect(songs.single.path, '/m/b.mp3');
    // Only b.mp3's favorite survives, now under ID 1.
    expect((await db.select(db.favorites).getSingle()).songId, 1);
  });

  group('tag fallbacks', () {
    test('candidates are songs with missing or non-ASCII tags', () async {
      await dao.applyScan([
        mediaSong(1, genre: 'Pop', year: 2020, track: 1),
        mediaSong(2, genre: 'Pop', track: 1), // no year
        mediaSong(3, genre: 'Pop', year: 2020, track: 1, artist: 'Beyoncé'),
      ]);
      final candidates = await dao.enrichmentCandidates();
      expect(candidates.map((s) => s.id), [2, 3]);
    });

    test('saved file tags merge into the song and survive a rescan', () async {
      final song = mediaSong(1, title: 'Seńorita', genre: 'Pop', track: 1);
      await dao.applyScan([song]);
      final candidate = (await dao.enrichmentCandidates()).single;

      await dao.saveFileTags([
        (
          candidate,
          const FileTagsResult.read(
            SongTags(title: 'Señorita', year: 2022, genre: 'Latin'),
          ),
        ),
      ], readAt: DateTime.utc(2026));

      var stored = (await allSongs()).single;
      expect(stored.title, 'Señorita');
      expect(stored.year, 2022);
      expect(stored.genre, 'Pop'); // MediaStore wins
      expect(stored.searchText, 'senorita');
      expect(await dao.enrichmentCandidates(), isEmpty);

      // MediaStore still reports the wrong text; the fallback is reapplied.
      final result = await dao.applyScan([song]);
      expect(result.changedAnything, isFalse);
      stored = (await allSongs()).single;
      expect(stored.title, 'Señorita');
      expect(stored.year, 2022);
    });

    test('a changed file is read again', () async {
      await dao.applyScan([mediaSong(1, genre: 'Pop', track: 1)]);
      final candidate = (await dao.enrichmentCandidates()).single;
      await dao.saveFileTags([
        (candidate, const FileTagsResult.read(SongTags(year: 2022))),
      ], readAt: DateTime.utc(2026));

      await dao.applyScan([
        mediaSong(1, genre: 'Pop', track: 1, modifiedSec: 1700009999),
      ]);

      expect((await allSongs()).single.year, isNull);
      expect(await dao.enrichmentCandidates(), hasLength(1));
    });

    test('failed reads are remembered and not retried', () async {
      await dao.applyScan([mediaSong(1)]);
      final candidate = (await dao.enrichmentCandidates()).single;
      await dao.saveFileTags([
        (candidate, const FileTagsResult.failed()),
      ], readAt: DateTime.utc(2026));

      expect(await dao.enrichmentCandidates(), isEmpty);
      expect((await db.select(db.songTagFallbacks).getSingle()).failed, isTrue);
    });

    test('the fallback follows a re-keyed song', () async {
      await dao.applyScan([mediaSong(1, path: '/m/a.mp3')]);
      final candidate = (await dao.enrichmentCandidates()).single;
      await dao.saveFileTags([
        (candidate, const FileTagsResult.read(SongTags(year: 1999))),
      ], readAt: DateTime.utc(2026));

      await dao.applyScan([mediaSong(7, path: '/m/a.mp3')]);

      final stored = (await allSongs()).single;
      expect(stored.id, 7);
      expect(stored.year, 1999);
    });
  });

  test('counts respect the minimum length', () async {
    await dao.applyScan([
      mediaSong(1, durationMs: 10000, path: '/a/x.mp3'),
      mediaSong(2, durationMs: 40000, path: '/a/y.mp3'),
      mediaSong(3, durationMs: 200000, path: '/b/z.mp3'),
    ]);

    final all = await dao.counts(minDurationMs: 0);
    expect(all.songs, 3);
    expect(all.folders, 2);

    final filtered = await dao.counts(minDurationMs: 30000);
    expect(filtered.songs, 2);
    expect(filtered.totalDuration, const Duration(seconds: 240));
  });
}
