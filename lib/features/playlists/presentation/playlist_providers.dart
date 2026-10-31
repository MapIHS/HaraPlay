import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/favorites_dao.dart';
import '../../../core/database/daos/playlists_dao.dart';
import '../domain/playlist_models.dart';

final favoritesDaoProvider = Provider<FavoritesDao>(
  (ref) => ref.watch(appDatabaseProvider).favoritesDao,
);

final playlistsDaoProvider = Provider<PlaylistsDao>(
  (ref) => ref.watch(appDatabaseProvider).playlistsDao,
);

final likedSongIdsProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(favoritesDaoProvider).watchLikedIds(),
);

/// Whether one song is liked; rebuilds only when that answer changes.
final isLikedProvider = Provider.family<bool, int>(
  (ref, songId) => ref.watch(
    likedSongIdsProvider.select((ids) => ids.value?.contains(songId) ?? false),
  ),
);

final likedSongsProvider = StreamProvider<List<SongRow>>(
  (ref) => ref.watch(favoritesDaoProvider).watchLikedSongs(),
);

final playlistsProvider = StreamProvider<List<PlaylistSummary>>(
  (ref) => ref.watch(playlistsDaoProvider).watchPlaylists(),
);

final playlistProvider = StreamProvider.autoDispose
    .family<PlaylistSummary?, int>(
      (ref, id) => ref.watch(playlistsDaoProvider).watchPlaylist(id),
    );

final playlistEntriesProvider = StreamProvider.autoDispose
    .family<List<PlaylistEntry>, int>(
      (ref, id) => ref.watch(playlistsDaoProvider).watchEntries(id),
    );

/// Playlists that already contain a song (add-to-playlist sheet).
final playlistsContainingProvider = StreamProvider.autoDispose
    .family<Set<int>, int>(
      (ref, songId) =>
          ref.watch(playlistsDaoProvider).watchPlaylistsContaining(songId),
    );

Future<void> setLiked(WidgetRef ref, int songId, {required bool liked}) => ref
    .read(favoritesDaoProvider)
    .setLiked(songId, liked: liked, at: DateTime.now());
