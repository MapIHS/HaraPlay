import 'package:drift/drift.dart';

import '../../utils/text_normalize.dart';
import '../app_database.dart';

part 'search_dao.g.dart';

/// The words of a search, folded like `songs.search_text`.
List<String> searchWords(String query) =>
    foldForSearch(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

/// [word] as a LIKE pattern matching it anywhere, with `%`, `_` and the
/// escape character itself taken literally.
String likeContains(String word) =>
    '%${word.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';

/// Song search over `search_text` (title, artist, album, album artist).
@DriftAccessor(tables: [Songs])
class SearchDao extends DatabaseAccessor<AppDatabase> with _$SearchDaoMixin {
  SearchDao(super.attachedDatabase);

  /// Songs containing every word of [query]. Titles that start with the
  /// first word come first, then by title.
  Future<List<SongRow>> searchSongs(
    String query, {
    required int minDurationMs,
    int limit = 500,
  }) async {
    final words = searchWords(query);
    if (words.isEmpty) return const [];
    final likes = List.filled(
      words.length,
      r"search_text LIKE ? ESCAPE '\'",
    ).join(' AND ');
    final rows = await customSelect(
      'SELECT * FROM songs WHERE duration_ms >= ? AND $likes '
      "ORDER BY search_text LIKE ? ESCAPE '\\' DESC, "
      'title COLLATE NOCASE LIMIT ?',
      variables: [
        Variable.withInt(minDurationMs),
        for (final w in words) Variable.withString(likeContains(w)),
        // search_text starts with the folded title.
        Variable.withString(likeContains(words.first).substring(1)),
        Variable.withInt(limit),
      ],
      readsFrom: {songs},
    ).get();
    return [for (final row in rows) songs.map(row.data)];
  }
}
