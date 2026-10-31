import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hara_colors.dart';
import 'mini_player.dart';
import 'now_playing_screen.dart';
import 'player_providers.dart';

/// Lets the shell (Android back) and Now Playing (collapse chevron) open
/// and close the [PlayerPanel].
class PlayerPanelController extends ChangeNotifier {
  _PlayerPanelState? _panel;

  bool get isExpanded => _panel?._isExpanded ?? false;

  void expand() => _panel?._settle(1);
  void collapse() => _panel?._settle(0);

  void _changed() => notifyListeners();
}

/// The mini player ↔ Now Playing panel, drawn above the tab content.
///
/// Collapsed, it is the mini player docked above the bottom navigation;
/// expanded, it covers the screen. It follows vertical drags and settles
/// with a critically damped spring, keeping the fling velocity.
class PlayerPanel extends ConsumerStatefulWidget {
  const PlayerPanel({
    super.key,
    required this.controller,
    required this.bottomInset,
  });

  final PlayerPanelController controller;

  /// Height of the bottom navigation (including the system inset) that the
  /// collapsed panel sits on.
  final double bottomInset;

  /// Fling speed (logical px/s) that decides the direction on release.
  static const double flingVelocity = 500;

  @override
  ConsumerState<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends ConsumerState<PlayerPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this)
    ..addStatusListener((_) => widget.controller._changed());

  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
  );

  /// Distance the panel's top edge travels between collapsed and expanded.
  double _travel = 1;

  bool get _isExpanded => _progress.value > 0.5;

  @override
  void initState() {
    super.initState();
    widget.controller._panel = this;
  }

  @override
  void didUpdateWidget(PlayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._panel = null;
      widget.controller._panel = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._panel == this) widget.controller._panel = null;
    _progress.dispose();
    super.dispose();
  }

  void _settle(double target, {double velocity = 0}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.value = target;
      return;
    }
    // The spring stops within its tolerance, not exactly on the target.
    // Snap to it: a panel left at 0.0001 keeps its full-height layout and
    // would cover the bottom navigation.
    _progress
        .animateWith(
          SpringSimulation(_spring, _progress.value, target, velocity),
        )
        .then((_) {
          if (mounted) _progress.value = target;
        });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _progress.value -= (details.primaryDelta ?? 0) / _travel;
  }

  void _onDragEnd(DragEndDetails details) {
    // Positive velocity is downwards, i.e. towards collapsed.
    final velocity = details.primaryVelocity ?? 0;
    final target = velocity <= -PlayerPanel.flingVelocity
        ? 1.0
        : velocity >= PlayerPanel.flingVelocity
        ? 0.0
        : (_progress.value > 0.5 ? 1.0 : 0.0);
    _settle(target, velocity: -velocity / _travel);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(playbackStatusProvider).value;
    if (status?.song == null) {
      if (_progress.value != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _progress.value = 0;
        });
      }
      return const SizedBox.shrink();
    }
    final colors = HaraColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final collapsedTop =
            height - widget.bottomInset - MiniPlayer.dockHeight;
        _travel = collapsedTop.clamp(1, double.infinity);

        return AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            // Treat a sliver of travel as fully collapsed (see _settle).
            final t = _progress.value < 0.001 ? 0.0 : _progress.value;
            final top = collapsedTop * (1 - t);
            final miniOpacity = (1 - t * 3).clamp(0.0, 1.0);
            final fullOpacity = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  bottom: t == 0 ? widget.bottomInset : 0,
                  // Outside the Scaffold, so it brings its own Material for
                  // ink and text defaults.
                  child: Material(
                    type: MaterialType.transparency,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (t > 0)
                            ColoredBox(
                              color: colors.background.withValues(
                                alpha: (t * 2).clamp(0.0, 1.0),
                              ),
                            ),
                          if (miniOpacity > 0)
                            Align(
                              alignment: Alignment.topCenter,
                              child: Opacity(
                                opacity: miniOpacity,
                                child: IgnorePointer(
                                  ignoring: t > 0.05,
                                  child: MiniPlayer(
                                    status: status!,
                                    onTap: () => _settle(1),
                                  ),
                                ),
                              ),
                            ),
                          // Always laid out at full height and clipped by
                          // the panel, so it slides instead of re-flowing.
                          if (fullOpacity > 0)
                            ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minHeight: height,
                                maxHeight: height,
                                child: Opacity(
                                  opacity: fullOpacity,
                                  child: IgnorePointer(
                                    ignoring: t < 0.95,
                                    child: NowPlayingScreen(
                                      onCollapse: () => _settle(0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
