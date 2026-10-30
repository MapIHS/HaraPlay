import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../core/theme/hara_colors.dart';
import '../../core/theme/hara_tokens.dart';

/// Keeps every tab's navigator alive (like an [IndexedStack]) and fades
/// through to the newly selected tab.
class BranchContainer extends StatefulWidget {
  const BranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<BranchContainer> createState() => _BranchContainerState();
}

class _BranchContainerState extends State<BranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HaraMotion.medium,
    value: 1,
  );

  @override
  void didUpdateWidget(BranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = HaraColors.of(context).background;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++) _branch(i, background),
      ],
    );
  }

  // The widget structure must stay identical whether or not a branch is
  // active, otherwise its navigator (and back stack) would be rebuilt.
  Widget _branch(int index, Color background) {
    final active = index == widget.currentIndex;
    return Offstage(
      offstage: !active,
      child: TickerMode(
        enabled: active,
        child: FadeThroughTransition(
          animation: active ? _controller : kAlwaysCompleteAnimation,
          secondaryAnimation: kAlwaysDismissedAnimation,
          fillColor: background,
          child: widget.children[index],
        ),
      ),
    );
  }
}
