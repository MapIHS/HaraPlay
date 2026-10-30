import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/browse_dao.dart';
import '../../../core/database/daos/library_dao.dart';
import '../../../core/storage/preferences.dart';
import '../../settings/presentation/min_song_length_controller.dart';
import '../data/library_sync_service.dart';
import '../domain/library_models.dart';
import '../domain/library_sort.dart';

/// Live song / album / folder counts under the current minimum length.
final libraryCountsProvider = StreamProvider<LibraryCounts>(
  (ref) => ref
      .watch(libraryDaoProvider)
      .watchCounts(minDurationMs: ref.watch(_minMsProvider)),
);

/// The state of the last user-visible library sync.
class LibrarySyncController extends Notifier<AsyncValue<SyncResult?>> {
  @override
  AsyncValue<SyncResult?> build() => const AsyncData(null);

  /// Syncs with MediaStore. Errors are kept in [state] and rethrown.
  Future<SyncResult> sync() async {
    state = const AsyncLoading<SyncResult?>();
    try {
      final result = await ref.read(librarySyncServiceProvider).sync();
      state = AsyncData(result);
      return result;
    } catch (error, stack) {
      state = AsyncError<SyncResult?>(error, stack);
      rethrow;
    }
  }
}

final librarySyncControllerProvider =
    NotifierProvider<LibrarySyncController, AsyncValue<SyncResult?>>(
      LibrarySyncController.new,
    );

final browseDaoProvider = Provider<BrowseDao>(
  (ref) => ref.watch(appDatabaseProvider).browseDao,
);

final _minMsProvider = Provider<int>(
  (ref) => ref.watch(minSongLengthProvider).inMilliseconds,
);

/// A tab's sort choice, persisted in preferences.
class SortController<F extends Enum> extends Notifier<LibrarySort<F>> {
  SortController(this._key, this._fields, this._default);

  final String _key;
  final List<F> _fields;
  final LibrarySort<F> _default;

  @override
  LibrarySort<F> build() =>
      LibrarySort.decode(
        ref.watch(sharedPreferencesProvider).getString(_key),
        _fields,
      ) ??
      _default;

  Future<void> set(LibrarySort<F> sort) async {
    if (sort == state) return;
    state = sort;
    await ref.read(sharedPreferencesProvider).setString(_key, sort.encode());
  }
}

final songSortProvider =
    NotifierProvider<SortController<SongSortField>, LibrarySort<SongSortField>>(
      () => SortController(
        'library.sort.songs',
        SongSortField.values,
        const LibrarySort(SongSortField.title),
      ),
    );

final albumSortProvider =
    NotifierProvider<
      SortController<AlbumSortField>,
      LibrarySort<AlbumSortField>
    >(
      () => SortController(
        'library.sort.albums',
        AlbumSortField.values,
        const LibrarySort(AlbumSortField.title),
      ),
    );

final artistSortProvider =
    NotifierProvider<
      SortController<ArtistSortField>,
      LibrarySort<ArtistSortField>
    >(
      () => SortController(
        'library.sort.artists',
        ArtistSortField.values,
        const LibrarySort(ArtistSortField.name),
      ),
    );

final folderSortProvider =
    NotifierProvider<
      SortController<FolderSortField>,
      LibrarySort<FolderSortField>
    >(
      () => SortController(
        'library.sort.folders',
        FolderSortField.values,
        const LibrarySort(FolderSortField.name),
      ),
    );

final genreSortProvider =
    NotifierProvider<
      SortController<GenreSortField>,
      LibrarySort<GenreSortField>
    >(
      () => SortController(
        'library.sort.genres',
        GenreSortField.values,
        const LibrarySort(GenreSortField.name),
      ),
    );

// Tab lists.

final songsProvider = StreamProvider<List<SongRow>>(
  (ref) => ref
      .watch(browseDaoProvider)
      .watchSongs(
        ref.watch(songSortProvider),
        minDurationMs: ref.watch(_minMsProvider),
      ),
);

final albumsProvider = StreamProvider<List<AlbumSummary>>(
  (ref) => ref
      .watch(browseDaoProvider)
      .watchAlbums(
        ref.watch(albumSortProvider),
        minDurationMs: ref.watch(_minMsProvider),
      ),
);

final artistsProvider = StreamProvider<List<ArtistSummary>>(
  (ref) => ref
      .watch(browseDaoProvider)
      .watchArtists(
        ref.watch(artistSortProvider),
        minDurationMs: ref.watch(_minMsProvider),
      ),
);

final foldersProvider = StreamProvider<List<FolderSummary>>(
  (ref) => ref
      .watch(browseDaoProvider)
      .watchFolders(
        ref.watch(folderSortProvider),
        minDurationMs: ref.watch(_minMsProvider),
      ),
);

final genresProvider = StreamProvider<List<GenreSummary>>(
  (ref) => ref
      .watch(browseDaoProvider)
      .watchGenres(
        ref.watch(genreSortProvider),
        minDurationMs: ref.watch(_minMsProvider),
      ),
);

// Detail screens.

final albumProvider = StreamProvider.autoDispose.family<AlbumSummary?, int>(
  (ref, albumId) => ref
      .watch(browseDaoProvider)
      .watchAlbum(albumId, minDurationMs: ref.watch(_minMsProvider)),
);

final albumSongsProvider = StreamProvider.autoDispose
    .family<List<SongRow>, int>(
      (ref, albumId) => ref
          .watch(browseDaoProvider)
          .watchAlbumSongs(albumId, minDurationMs: ref.watch(_minMsProvider)),
    );

/// Keyed by artist name; null is "Unknown artist".
final artistSongsProvider = StreamProvider.autoDispose
    .family<List<SongRow>, String?>(
      (ref, artist) => ref
          .watch(browseDaoProvider)
          .watchArtistSongs(artist, minDurationMs: ref.watch(_minMsProvider)),
    );

final artistAlbumsProvider = StreamProvider.autoDispose
    .family<List<AlbumSummary>, String?>(
      (ref, artist) => ref
          .watch(browseDaoProvider)
          .watchAlbumsOfArtist(
            artist,
            minDurationMs: ref.watch(_minMsProvider),
          ),
    );

final folderSongsProvider = StreamProvider.autoDispose
    .family<List<SongRow>, String>(
      (ref, path) => ref
          .watch(browseDaoProvider)
          .watchFolderSongs(path, minDurationMs: ref.watch(_minMsProvider)),
    );

final genreSongsProvider = StreamProvider.autoDispose
    .family<List<SongRow>, String>(
      (ref, genre) => ref
          .watch(browseDaoProvider)
          .watchGenreSongs(genre, minDurationMs: ref.watch(_minMsProvider)),
    );

/// One song by ID (song info sheet); null if it no longer exists.
final songByIdProvider = FutureProvider.autoDispose.family<SongRow?, int>(
  (ref, id) =>
      (ref
              .watch(appDatabaseProvider)
              .select(ref.watch(appDatabaseProvider).songs)
            ..where((s) => s.id.equals(id)))
          .getSingleOrNull(),
);
