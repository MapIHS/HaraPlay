import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/hara_tokens.dart';
import '../../features/player/presentation/mini_player.dart';
import '../../features/player/presentation/player_panel.dart';
import '../../features/player/presentation/player_providers.dart';
import 'bottom_nav.dart';

/// Scaffold around the four tabs: tab content, the bottom navigation, and
/// the player panel (docked mini player ↔ Now Playing) drawn above both.
///
/// Android back first collapses Now Playing, then pops the current tab's
/// own stack (handled by go_router). At a tab root it returns to Home; on
/// Home it leaves the app.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _panel = PlayerPanelController();

  @override
  void dispose() {
    _panel.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    _panel.collapse();
    // Re-selecting the current tab pops it back to its root.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final hasSong = ref.watch(currentSongIdProvider) != null;
    final bottomInset =
        HaraBottomNav.height +
        HaraBorder.regular +
        MediaQuery.viewPaddingOf(context).bottom;

    return ListenableBuilder(
      listenable: _panel,
      builder: (context, child) => PopScope(
        canPop: shell.currentIndex == 0 && !_panel.isExpanded,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_panel.isExpanded) {
            _panel.collapse();
          } else {
            shell.goBranch(0);
          }
        },
        child: child!,
      ),
      child: Stack(
        children: [
          Scaffold(
            body: shell,
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Room for the docked mini player, which the panel draws.
                if (hasSong) const SizedBox(height: MiniPlayer.dockHeight),
                HaraBottomNav(
                  currentIndex: shell.currentIndex,
                  onSelected: _selectTab,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: PlayerPanel(controller: _panel, bottomInset: bottomInset),
          ),
        ],
      ),
    );
  }
}
