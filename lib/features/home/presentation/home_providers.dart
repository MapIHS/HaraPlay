import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/home_dao.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_providers.dart';

final homeDaoProvider = Provider<HomeDao>(
  (ref) => ref.watch(appDatabaseProvider).homeDao,
);

final recentlyPlayedProvider = StreamProvider<List<SongRow>>(
  (ref) => ref
      .watch(homeDaoProvider)
      .watchRecentlyPlayed(minDurationMs: ref.watch(minDurationMsProvider)),
);

final mostPlayedProvider = StreamProvider<List<PlayedSong>>(
  (ref) => ref
      .watch(homeDaoProvider)
      .watchMostPlayed(minDurationMs: ref.watch(minDurationMsProvider)),
);

final recentlyAddedAlbumsProvider = StreamProvider<List<AlbumSummary>>(
  (ref) => ref
      .watch(browseDaoProvider)
      .watchRecentlyAddedAlbums(
        minDurationMs: ref.watch(minDurationMsProvider),
      ),
);
