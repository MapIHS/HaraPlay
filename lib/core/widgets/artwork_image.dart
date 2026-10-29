import 'package:flutter/material.dart';

import '../icons/hara_icons.dart';
import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';

/// Square album/song artwork with an outline, optional hard shadow, and a
/// placeholder when there is no image (or it fails to load).
///
/// [seed] (e.g. the album id) picks a stable accent colour for the
/// placeholder so a grid of missing covers doesn't look uniform.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.size,
    this.image,
    this.seed = 0,
    this.borderRadius = HaraRadius.md,
    this.borderWidth = HaraBorder.thin,
    this.shadow = false,
  });

  final double size;
  final ImageProvider? image;
  final int seed;
  final double borderRadius;
  final double borderWidth;

  /// Adds a hard offset shadow (used for large artwork).
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final radius = BorderRadius.circular(borderRadius);
    final innerRadius = BorderRadius.circular(
      (borderRadius - borderWidth).clamp(0, borderRadius),
    );
    final shadowOffset = size >= 120 ? HaraShadow.offset : HaraShadow.small;

    final placeholder = _Placeholder(
      color: colors.accents[seed.abs() % colors.accents.length],
      iconColor: colors.foreground.withValues(alpha: 0.55),
      iconSize: size * 0.4,
    );

    final Widget content = image == null
        ? placeholder
        : Image(
            image: image!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: HaraMotion.medium,
                curve: HaraMotion.decelerate,
                child: child,
              );
            },
          );

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: radius,
          border: Border.all(color: colors.border, width: borderWidth),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: colors.shadow,
                    offset: Offset(shadowOffset, shadowOffset),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(borderRadius: innerRadius, child: content),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.color,
    required this.iconColor,
    required this.iconSize,
  });

  final Color color;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Icon(HaraIcons.music, size: iconSize, color: iconColor),
      ),
    );
  }
}
