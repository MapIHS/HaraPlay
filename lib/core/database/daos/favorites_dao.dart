import 'package:drift/drift.dart';

import '../app_database.dart';

part 'favorites_dao.g.dart';

/// Liked songs. Not filtered by the minimum length: a song the user liked
/// stays visible here.
@DriftAccessor(tables: [Favorites, Songs])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.attachedDatabase);

  Stream<Set<int>> watchLikedIds() {
    final query = selectOnly(favorites)..addColumns([favorites.songId]);
    return query.watch().map(
      (rows) => {for (final row in rows) row.read(favorites.songId)!},
    );
  }

  /// Most recently liked first.
  Stream<List<SongRow>> watchLikedSongs() {
    final query =
        select(songs)
            .join([innerJoin(favorites, favorites.songId.equalsExp(songs.id))])
          ..orderBy([
            OrderingTerm.desc(favorites.addedAt),
            OrderingTerm.asc(songs.id),
          ]);
    return query.watch().map(
      (rows) => [for (final row in rows) row.readTable(songs)],
    );
  }

  /// Likes or unlikes [songId]. Does nothing for a song that no longer
  /// exists.
  Future<void> setLiked(
    int songId, {
    required bool liked,
    required DateTime at,
  }) async {
    if (!liked) {
      await (delete(favorites)..where((f) => f.songId.equals(songId))).go();
      return;
    }
    await customInsert(
      'INSERT OR IGNORE INTO favorites (song_id, song_path, added_at) '
      'SELECT id, path, ? FROM songs WHERE id = ?',
      variables: [
        Variable.withInt(at.millisecondsSinceEpoch),
        Variable.withInt(songId),
      ],
      updates: {favorites},
    );
  }
}
