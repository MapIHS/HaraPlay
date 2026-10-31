import 'package:flutter/material.dart';

import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';
import '../theme/hara_typography.dart';
import 'hara_pressable.dart';

/// A small bordered chip, e.g. a stat chip "2020 YEAR" or a tag "ROCK".
///
/// [value] (optional) is shown in bold mono before the uppercase [label].
class HaraChip extends StatelessWidget {
  const HaraChip({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.color,
    this.onPressed,
  });

  final String label;
  final String? value;
  final IconData? icon;

  /// Fill colour; defaults to the surface colour. Pass an accent for tags.
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return HaraPressable(
      onPressed: onPressed,
      isButton: onPressed != null,
      semanticLabel: value == null ? label : '$value $label',
      color: color ?? colors.surface,
      borderRadius: HaraRadius.sm,
      borderWidth: HaraBorder.thin,
      shadowOffset: HaraShadow.small,
      padding: const EdgeInsets.symmetric(
        horizontal: HaraSpacing.sm + 2,
        vertical: HaraSpacing.xs + 2,
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: colors.foreground),
              const SizedBox(width: HaraSpacing.xs + 2),
            ],
            if (value != null) ...[
              Text(value!, style: HaraTextStyles.of(context).monoStrong),
              const SizedBox(width: HaraSpacing.xs + 2),
            ],
            // Shrinks with an ellipsis when large text makes the chip
            // wider than the screen.
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: textTheme.labelMedium!.copyWith(
                  color: value == null
                      ? colors.foreground
                      : colors.mutedForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
