import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/design_gallery/presentation/design_gallery_screen.dart';
import '../features/favorites/presentation/liked_songs_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/album_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/playlists/presentation/playlists_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell/app_shell.dart';
import 'shell/branch_container.dart';

/// Route paths. Tab roots are listed in bottom-nav order.
abstract final class AppRoutes {
  static const home = '/home';
  static const library = '/library';
  static const search = '/search';
  static const playlists = '/playlists';
  static const settings = '/settings';
  static const designGallery = '/settings/gallery';
  static const likedSongs = '/playlists/favorites';

  static String album(int albumId) => '/library/album/$albumId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createRouter({String initialLocation = AppRoutes.home}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
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
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'album/:albumId',
                    builder: (context, state) => AlbumScreen(
                      albumId: int.parse(state.pathParameters['albumId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.playlists,
                builder: (context, state) => const PlaylistsScreen(),
                routes: [
                  GoRoute(
                    path: 'favorites',
                    builder: (context, state) => const LikedSongsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes above the shell (no bottom nav).
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          if (kDebugMode)
            GoRoute(
              path: 'gallery',
              builder: (context, state) => const DesignGalleryScreen(),
            ),
        ],
      ),
    ],
  );
}
