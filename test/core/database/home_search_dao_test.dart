import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/search_dao.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  /// A listen of [songId] at minute [at] lasting [listenedSec].
  Future<void> listen(int songId, int at, int listenedSec, {int dur = 180}) =>
      db.playEventsDao.insertEvent(
        PlayEventsCompanion.insert(
          songId: Value(songId),
          songPath: '/m/$songId',
          title: 'Song $songId',
          startedAt: at * 60000,
          listenedMs: listenedSec * 1000,
          durationMs: dur * 1000,
          completed: false,
          source: PlaySource.songs,
        ),
      );

  group('home', () {
    setUp(() async {
      await db.libraryDao.applyScan([
        mediaSong(1, albumId: 1),
        mediaSong(2, albumId: 1),
        mediaSong(3, albumId: 2),
        mediaSong(4, albumId: 2, durationMs: 40000),
        mediaSong(5, albumId: 3, durationMs: 10000), // hidden: too short
      ]);
    });

    test(
      'recently played: counted plays only, newest first, once each',
      () async {
        await listen(1, 1, 120);
        await listen(2, 2, 31);
        await listen(3, 3, 5); // a skip: not a play
        await listen(1, 4, 40);
        await listen(4, 5, 20, dur: 40); // half of a 40 s song counts
        await listen(5, 6, 10); // hidden song

        final ids = [
          for (final s
              in await db.homeDao
                  .watchRecentlyPlayed(minDurationMs: 30000)
                  .first)
            s.id,
        ];
        expect(ids, [4, 1, 2]);
      },
    );

    test('most played: by count, ties to the latest', () async {
      await listen(2, 1, 60);
      await listen(2, 2, 60);
      await listen(1, 3, 60);
      await listen(3, 4, 60);
      await listen(1, 5, 10); // skip, does not count

      final top = await db.homeDao.watchMostPlayed(minDurationMs: 30000).first;
      expect(
        [for (final p in top) (p.song.id, p.plays)],
        [(2, 2), (3, 1), (1, 1)],
      );
    });

    test('history of a deleted song drops out of the rows', () async {
      await listen(3, 1, 60);
      await db.libraryDao.applyScan([mediaSong(1, albumId: 1)]);
      expect(
        await db.homeDao.watchRecentlyPlayed(minDurationMs: 0).first,
        isEmpty,
      );
    });

    test('recently added albums: newest addition first', () async {
      await db.libraryDao.applyScan([
        mediaSong(1, albumId: 1),
        mediaSong(3, albumId: 2),
      ]);
      // Album 2 gets a newer song.
      await db.customStatement(
        'UPDATE songs SET date_added = date_added + 100 WHERE id = 3',
      );
      final albums = await db.browseDao
          .watchRecentlyAddedAlbums(minDurationMs: 0)
          .first;
      expect([for (final a in albums) a.albumId], [2, 1]);
    });
  });

  group('search', () {
    setUp(() async {
      await db.libraryDao.applyScan([
        mediaSong(1, title: 'Night Drive', artist: 'Mono Lisa', albumId: 1),
        mediaSong(2, title: 'Drive Home', artist: 'Kai Tone', albumId: 2),
        mediaSong(
          3,
          title: 'Señorita Café',
          artist: 'Beyoncé Sinewave',
          albumId: 3,
        ),
        mediaSong(4, title: '100% Pure', artist: 'Kai Tone', albumId: 2),
        mediaSong(5, title: 'Drive Short', albumId: 4, durationMs: 9000),
      ]);
    });

    Future<List<String>> titles(String q, {int min = 30000}) async => [
      for (final s in await db.searchDao.searchSongs(q, minDurationMs: min))
        s.title,
    ];

    test('every word must match; title prefix ranks first', () async {
      expect(await titles('drive'), ['Drive Home', 'Night Drive']);
      expect(await titles('drive kai'), ['Drive Home']);
      expect(await titles('  '), isEmpty);
    });

    test('accents and case are ignored', () async {
      expect(await titles('SENORITA cafe'), ['Señorita Café']);
      expect(await titles('beyonce'), ['Señorita Café']);
    });

    test('% and _ are matched literally', () async {
      expect(await titles('100%'), ['100% Pure']);
      expect(await titles('_'), isEmpty);
      expect(await titles('%'), ['100% Pure']);
    });

    test('hidden short songs are left out', () async {
      expect(await titles('short'), isEmpty);
      expect(await titles('short', min: 0), ['Drive Short']);
    });

    test('likeContains escapes wildcards', () {
      expect(likeContains(r'a%b_c\d'), r'%a\%b\_c\\d%');
      expect(searchWords('  Café   DEL  '), ['cafe', 'del']);
    });

    test('5,000 songs: a query takes well under 50 ms', () async {
      await db.libraryDao.applyScan([
        for (var i = 0; i < 5000; i++)
          mediaSong(
            10000 + i,
            title: 'Track $i ${i.isEven ? 'Sunrise' : 'Sunset'}',
            artist: 'Artist ${i % 300}',
            album: 'Album ${i % 400}',
            albumId: i % 400,
            path: '/m/bulk/$i.mp3',
          ),
      ]);
      // Warm up, then time a few typical queries.
      await db.searchDao.searchSongs('sun', minDurationMs: 30000);
      final watch = Stopwatch()..start();
      for (final q in ['sun', 'artist 12', 'track 4999', 'album 3 sunset']) {
        await db.searchDao.searchSongs(q, minDurationMs: 30000);
      }
      final perQuery = watch.elapsedMilliseconds / 4;
      expect(perQuery, lessThan(50), reason: '$perQuery ms per query');
    });
  });
}
