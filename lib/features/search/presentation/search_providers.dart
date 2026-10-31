import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/search_dao.dart';
import '../../../core/storage/preferences.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_providers.dart';

/// Matches in each group, best first.
class SearchResults {
  const SearchResults({
    required this.songs,
    required this.albums,
    required this.artists,
  });

  static const empty = SearchResults(songs: [], albums: [], artists: []);

  final List<SongRow> songs;
  final List<AlbumSummary> albums;
  final List<ArtistSummary> artists;

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;
}

final searchDaoProvider = Provider<SearchDao>(
  (ref) => ref.watch(appDatabaseProvider).searchDao,
);

/// Whether every word of [words] occurs in [text] (already folded).
bool _matchesAll(String? text, List<String> words) {
  if (text == null) return false;
  final folded = searchWords(text).join(' ');
  return words.every(folded.contains);
}

/// Results for one (debounced) query. Songs come from SQL; albums and
/// artists are filtered from the browse lists, which are already loaded and
/// small in comparison.
final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>((ref, query) async {
      final words = searchWords(query);
      if (words.isEmpty) return SearchResults.empty;
      final songs = await ref
          .watch(searchDaoProvider)
          .searchSongs(query, minDurationMs: ref.watch(minDurationMsProvider));
      final albums = await ref.watch(albumsProvider.future);
      final artists = await ref.watch(artistsProvider.future);
      return SearchResults(
        songs: songs,
        albums: [
          for (final a in albums)
            if (_matchesAll('${a.title ?? ''} ${a.artist ?? ''}', words)) a,
        ],
        artists: [
          for (final a in artists)
            if (_matchesAll(a.name, words)) a,
        ],
      );
    });

/// The last searches the user acted on, newest first.
class RecentSearchesController extends Notifier<List<String>> {
  static const _key = 'search.recent';
  static const maxEntries = 8;

  @override
  List<String> build() =>
      ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final lower = q.toLowerCase();
    await _save(
      [
        q,
        for (final s in state)
          if (s.toLowerCase() != lower) s,
      ].take(maxEntries).toList(),
    );
  }

  Future<void> remove(String query) => _save([
    for (final s in state)
      if (s != query) s,
  ]);

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> list) async {
    state = list;
    await ref.read(sharedPreferencesProvider).setStringList(_key, list);
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
      RecentSearchesController.new,
    );
