import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/design_gallery/presentation/design_gallery_screen.dart';
import '../features/design_gallery/presentation/media_store_debug_screen.dart';
import '../features/favorites/presentation/liked_songs_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/album_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/onboarding/data/media_permission_service.dart';
import '../features/onboarding/presentation/onboarding_controllers.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
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
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const designGallery = '/settings/gallery';
  static const mediaStoreDebug = '/settings/media-store';
  static const likedSongs = '/playlists/favorites';

  static String album(int albumId) => '/library/album/$albumId';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever access or onboarding state changes.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(mediaAccessProvider, (_, _) => refresh.value++)
    ..listen(onboardingCompletedProvider, (_, _) => refresh.value++);

  final router = createRouter(
    refreshListenable: refresh,
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
          if (kDebugMode) ...[
            GoRoute(
              path: 'gallery',
              builder: (context, state) => const DesignGalleryScreen(),
            ),
            GoRoute(
              path: 'media-store',
              builder: (context, state) => const MediaStoreDebugScreen(),
            ),
          ],
        ],
      ),
    ],
  );
}
