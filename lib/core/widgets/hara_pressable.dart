import 'package:flutter/material.dart';

import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';

/// A bordered surface with a hard offset shadow that "presses in" on touch:
/// the face slides onto its shadow, which disappears.
///
/// Layout reserves [shadowOffset] on the right and bottom so pressing never
/// overlaps neighbours. Interactive only when [onPressed] or [onLongPress]
/// is set; otherwise it renders as a static card.
class HaraPressable extends StatefulWidget {
  const HaraPressable({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.color,
    this.borderRadius = HaraRadius.md,
    this.borderWidth = HaraBorder.regular,
    this.shadowOffset = HaraShadow.offset,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.isButton = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Face colour; defaults to [HaraColors.surface].
  final Color? color;
  final double borderRadius;

  /// Set to 0 to drop the outline.
  final double borderWidth;

  /// Set to 0 to drop the shadow (and the press-in movement).
  final double shadowOffset;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  /// Whether to expose button semantics when interactive.
  final bool isButton;

  static const faceKey = ValueKey('hara-pressable-face');

  @override
  State<HaraPressable> createState() => _HaraPressableState();
}

class _HaraPressableState extends State<HaraPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final radius = BorderRadius.circular(widget.borderRadius);
    final offset = widget.shadowOffset;
    final animate = !MediaQuery.disableAnimationsOf(context);

    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color ?? colors.surface,
        borderRadius: radius,
        border: widget.borderWidth > 0
            ? Border.all(color: colors.border, width: widget.borderWidth)
            : null,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    Widget result = Padding(
      padding: EdgeInsets.only(right: offset, bottom: offset),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? 1 : 0),
        duration: animate ? HaraMotion.fast : Duration.zero,
        curve: Curves.easeOut,
        child: face,
        builder: (context, t, child) {
          final shift = offset * t;
          final shadow = offset - shift;
          return Transform.translate(
            key: HaraPressable.faceKey,
            offset: Offset(shift, shift),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: shadow > 0
                    ? [
                        BoxShadow(
                          color: colors.shadow,
                          offset: Offset(shadow, shadow),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          );
        },
      ),
    );

    if (!_enabled) {
      return Semantics(
        label: widget.semanticLabel,
        button: widget.isButton ? true : null,
        enabled: widget.isButton ? false : null,
        child: result,
      );
    }

    result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: result,
    );

    return Semantics(
      label: widget.semanticLabel,
      button: widget.isButton,
      enabled: true,
      child: result,
    );
  }
}
