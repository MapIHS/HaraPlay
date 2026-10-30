import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/presentation/mini_player.dart';
import 'bottom_nav.dart';

/// Scaffold around the four tabs: tab content, the docked mini player, and
/// the bottom navigation.
///
/// Android back first pops the current tab's own stack (handled by
/// go_router). At a tab root it returns to Home; on Home it leaves the app.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _selectTab(int index) {
    // Re-selecting the current tab pops it back to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onHome = navigationShell.currentIndex == 0;
    return PopScope(
      canPop: onHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            HaraBottomNav(
              currentIndex: navigationShell.currentIndex,
              onSelected: _selectTab,
            ),
          ],
        ),
      ),
    );
  }
}
