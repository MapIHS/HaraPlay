import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons/hara_icons.dart';
import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';

/// A filled, outlined heart: the "liked" mark. The icon font only has an
/// outline heart, which reads as "tap to like".
class HeartMark extends StatelessWidget {
  const HeartMark({super.key, this.size = 16, this.semanticLabel, this.fill});

  final double size;

  /// Defaults to the brand fill; pass another colour on a brand background.
  final Color? fill;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _HeartPainter(
          fill: fill ?? colors.primary,
          stroke: colors.border,
          strokeWidth: size >= 24 ? HaraBorder.regular : HaraBorder.thin,
        ),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  /// Two lobes and a point, inset so the stroke stays inside [size].
  Path _heart(Size size) {
    final inset = strokeWidth / 2 + size.width * 0.06;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    final r = w / 4;
    final lobeY = inset + h * 0.06 + r;
    final left = Offset(inset + r, lobeY);
    final right = Offset(inset + w - r, lobeY);
    final tip = Offset(inset + w / 2, inset + h * 0.94);
    // Where the sides leave the lobes: 45° below the outer edges.
    const side = math.pi * 0.75;
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx + r * math.cos(side), left.dy + r * math.sin(side))
      ..arcTo(
        Rect.fromCircle(center: left, radius: r),
        side,
        math.pi * 1.25,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: right, radius: r),
        math.pi,
        math.pi * 1.25,
        false,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _heart(size);
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.fill != fill ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}

/// The like toggle: an outline heart, or a filled [HeartMark] once liked.
class LikeButton extends StatelessWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.onPressed,
    this.size = HaraSizes.minTouchTarget,
    this.iconSize = HaraSizes.icon,
  });

  final bool liked;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final tooltip = liked ? 'Remove from Liked songs' : 'Add to Liked songs';
    return Semantics(
      label: 'Like',
      toggled: liked,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: Material(
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: onPressed,
              radius: size / 2,
              child: Center(
                child: AnimatedSwitcher(
                  duration: HaraMotion.fast,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: liked
                      ? HeartMark(key: const ValueKey(true), size: iconSize + 2)
                      : Icon(
                          HaraIcons.heart,
                          key: const ValueKey(false),
                          size: iconSize,
                          color: colors.foreground,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
