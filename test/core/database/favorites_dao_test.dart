import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/favorites_dao.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FavoritesDao dao;
  final at = DateTime.utc(2026, 10, 31, 12);

  setUp(() async {
    db = createTestDatabase();
    dao = db.favoritesDao;
    await db.libraryDao.applyScan([
      for (var id = 1; id <= 3; id++) mediaSong(id, albumId: id),
      mediaSong(4, durationMs: 5000),
    ]);
  });
  tearDown(() => db.close());

  test('like, unlike, newest first, short songs included', () async {
    await dao.setLiked(2, liked: true, at: at);
    await dao.setLiked(4, liked: true, at: at.add(const Duration(seconds: 1)));
    await dao.setLiked(1, liked: true, at: at.add(const Duration(seconds: 2)));

    expect(
      [for (final s in await dao.watchLikedSongs().first) s.id],
      [1, 4, 2],
    );
    expect(await dao.watchLikedIds().first, {1, 2, 4});

    await dao.setLiked(4, liked: false, at: at);
    expect(await dao.watchLikedIds().first, {1, 2});
  });

  test('liking twice keeps the first date', () async {
    await dao.setLiked(1, liked: true, at: at);
    await dao.setLiked(2, liked: true, at: at.add(const Duration(seconds: 1)));
    await dao.setLiked(1, liked: true, at: at.add(const Duration(seconds: 2)));
    expect([for (final s in await dao.watchLikedSongs().first) s.id], [2, 1]);
  });

  test('liking a missing song does nothing', () async {
    await dao.setLiked(99, liked: true, at: at);
    expect(await dao.watchLikedIds().first, isEmpty);
  });

  test('likes follow a re-keyed song and vanish with a deleted one', () async {
    await dao.setLiked(1, liked: true, at: at);
    await dao.setLiked(2, liked: true, at: at);
    await db.libraryDao.applyScan([
      mediaSong(50, path: '/storage/emulated/0/Music/song1.mp3', albumId: 1),
      mediaSong(3, albumId: 3),
    ]);
    expect(await dao.watchLikedIds().first, {50});
  });
}
