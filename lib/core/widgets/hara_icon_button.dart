import 'package:flutter/material.dart';

import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';
import 'hara_pressable.dart';

enum HaraIconButtonVariant {
  /// Icon only, no outline (toolbar and transport side buttons).
  plain,

  /// Square brand fill with outline and hard shadow (play/pause).
  primary,

  /// Square surface fill with outline and hard shadow.
  outline,
}

/// An icon button with a 48dp minimum touch target.
///
/// A [plain] button with [selected] set renders as [primary], which is how
/// toggles such as shuffle and repeat show their "on" state.
class HaraIconButton extends StatelessWidget {
  const HaraIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = HaraIconButtonVariant.plain,
    this.selected = false,
    this.size = HaraSizes.minTouchTarget,
    this.iconSize,
  });

  final IconData icon;

  /// Shown on long-press and used as the accessibility label.
  final String tooltip;
  final VoidCallback? onPressed;
  final HaraIconButtonVariant variant;
  final bool selected;

  /// Outer square size (including the shadow for bordered variants).
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final enabled = onPressed != null;
    final effective = variant == HaraIconButtonVariant.plain && selected
        ? HaraIconButtonVariant.primary
        : variant;
    final resolvedIconSize = iconSize ?? HaraSizes.icon;

    final Widget button;
    if (effective == HaraIconButtonVariant.plain) {
      button = SizedBox.square(
        dimension: size,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onPressed,
            radius: size / 2,
            child: Center(
              child: Icon(
                icon,
                size: resolvedIconSize,
                color: colors.foreground,
              ),
            ),
          ),
        ),
      );
    } else {
      final isPrimary = effective == HaraIconButtonVariant.primary;
      final shadow = size >= 56 ? HaraShadow.offset : HaraShadow.small;
      button = SizedBox.square(
        dimension: size,
        child: HaraPressable(
          onPressed: onPressed,
          color: isPrimary ? colors.primary : colors.surface,
          borderRadius: size >= 56 ? HaraRadius.lg : HaraRadius.md,
          shadowOffset: enabled ? shadow : 0,
          child: Center(
            child: Icon(
              icon,
              size: resolvedIconSize,
              color: isPrimary ? colors.onPrimary : colors.foreground,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: tooltip,
      selected: selected,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Opacity(opacity: enabled ? 1 : 0.45, child: button),
      ),
    );
  }
}
