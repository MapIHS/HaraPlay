import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/design_gallery/presentation/design_gallery_screen.dart';
import '../features/design_gallery/presentation/library_database_debug_screen.dart';
import '../features/design_gallery/presentation/media_store_debug_screen.dart';
import '../features/equalizer/presentation/equalizer_screen.dart';
import '../features/favorites/presentation/liked_songs_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/album_detail_screen.dart';
import '../features/library/presentation/artist_detail_screen.dart';
import '../features/library/presentation/folder_detail_screen.dart';
import '../features/library/presentation/genre_detail_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/onboarding/data/media_permission_service.dart';
import '../features/onboarding/presentation/onboarding_controllers.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/playlists/presentation/playlist_detail_screen.dart';
import '../features/playlists/presentation/playlists_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/excluded_folders_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/stats/presentation/stats_screen.dart';
import 'features.dart';
import 'shell/app_shell.dart';
import 'shell/branch_container.dart';

/// Route paths. Tab roots are listed in bottom-nav order.
abstract final class AppRoutes {
  static const home = '/home';
  static const library = '/library';
  static const search = '/search';
  static const playlists = '/playlists';
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const stats = '/stats';
  static const equalizer = '/equalizer';
  static const excludedFolders = '/settings/excluded-folders';
  static const designGallery = '/settings/gallery';
  static const mediaStoreDebug = '/settings/media-store';
  static const libraryDatabaseDebug = '/settings/library-database';
  static const likedSongs = '/playlists/favorites';

  static String playlist(int id) => '/playlists/$id';

  /// Detail pages exist under every tab root, so a link opens them in the
  /// current tab and Back returns there. [tab] is a tab root (see
  /// [currentTab]); it defaults to the Library.
  static String album(int albumId, {String tab = library}) =>
      '$tab/album/$albumId';

  /// Null opens "Unknown artist".
  static String artist(String? name, {String tab = library}) => Uri(
    path: '$tab/artist',
    queryParameters: name == null ? null : {'name': name},
  ).toString();

  static String folder(String path, {String tab = library}) =>
      Uri(path: '$tab/folder', queryParameters: {'path': path}).toString();

  static String genre(String name, {String tab = library}) =>
      Uri(path: '$tab/genre', queryParameters: {'name': name}).toString();

  static const tabs = [home, library, search, playlists];
}

/// The tab root of the router's current location; the Library for pages
/// outside the tabs (Settings).
String currentTab(GoRouter router) {
  final path = router.routerDelegate.currentConfiguration.uri.path;
  for (final tab in AppRoutes.tabs) {
    if (path == tab || path.startsWith('$tab/')) return tab;
  }
  return AppRoutes.library;
}

/// Album, artist, folder and genre pages, registered under each tab root.
List<RouteBase> _detailRoutes() => [
  GoRoute(
    path: 'album/:albumId',
    builder: (context, state) => AlbumDetailScreen(
      albumId: int.tryParse(state.pathParameters['albumId']!) ?? -1,
    ),
  ),
  GoRoute(
    path: 'artist',
    builder: (context, state) =>
        ArtistDetailScreen(name: state.uri.queryParameters['name']),
  ),
  GoRoute(
    path: 'folder',
    builder: (context, state) =>
        FolderDetailScreen(path: state.uri.queryParameters['path'] ?? ''),
  ),
  GoRoute(
    path: 'genre',
    builder: (context, state) =>
        GenreDetailScreen(name: state.uri.queryParameters['name'] ?? ''),
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever access or onboarding state changes.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(mediaAccessProvider, (_, _) => refresh.value++)
    ..listen(onboardingCompletedProvider, (_, _) => refresh.value++);

  final router = createRouter(
    refreshListenable: refresh,
    equalizer: ref.read(equalizerEnabledProvider),
    redirect: (context, state) => onboardingRedirect(
      access: ref.read(mediaAccessProvider),
      completed: ref.read(onboardingCompletedProvider),
      location: state.matchedLocation,
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Keeps the user on onboarding until library access is granted and the
/// first scan is done, and away from it afterwards.
String? onboardingRedirect({
  required MediaAccess access,
  required bool completed,
  required String location,
}) {
  final onOnboarding = location == AppRoutes.onboarding;
  final needsOnboarding = access != MediaAccess.granted || !completed;
  if (needsOnboarding) return onOnboarding ? null : AppRoutes.onboarding;
  return onOnboarding ? AppRoutes.home : null;
}

GoRouter createRouter({
  String initialLocation = AppRoutes.home,
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
  bool equalizer = kEqualizerEnabled,
}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            BranchContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) => const LibraryScreen(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchScreen(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.playlists,
                builder: (context, state) => const PlaylistsScreen(),
                routes: [
                  // Before ':playlistId', which would match "album" too.
                  ..._detailRoutes(),
                  GoRoute(
                    path: 'favorites',
                    builder: (context, state) => const LikedSongsScreen(),
                  ),
                  GoRoute(
                    path: ':playlistId',
                    builder: (context, state) => PlaylistDetailScreen(
                      playlistId:
                          int.tryParse(state.pathParameters['playlistId']!) ??
                          -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes above the shell (no bottom nav).
      if (equalizer)
        GoRoute(
          path: AppRoutes.equalizer,
          parentNavigatorKey: rootKey,
          builder: (context, state) => const EqualizerScreen(),
        ),
      GoRoute(
        path: AppRoutes.excludedFolders,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const ExcludedFoldersScreen(),
      ),
      GoRoute(
        path: AppRoutes.stats,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          if (kDebugMode) ...[
            GoRoute(
              path: 'gallery',
              builder: (context, state) => const DesignGalleryScreen(),
            ),
            GoRoute(
              path: 'media-store',
              builder: (context, state) => const MediaStoreDebugScreen(),
            ),
            GoRoute(
              path: 'library-database',
              builder: (context, state) => const LibraryDatabaseDebugScreen(),
            ),
          ],
        ],
      ),
    ],
  );
}
