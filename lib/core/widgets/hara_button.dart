import 'package:flutter/material.dart';

import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';
import 'hara_pressable.dart';

enum HaraButtonVariant {
  /// Brand fill, outline and hard shadow. One per screen area.
  primary,

  /// Surface fill, outline and hard shadow.
  secondary,

  /// Text only, for low-emphasis actions ("See all", "Cancel").
  ghost,
}

enum HaraButtonSize { regular, small }

class HaraButton extends StatelessWidget {
  const HaraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = HaraButtonVariant.primary,
    this.size = HaraButtonSize.regular,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final HaraButtonVariant variant;
  final HaraButtonSize size;

  /// Stretch to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final enabled = onPressed != null;
    final small = size == HaraButtonSize.small;
    final height = small ? 40.0 : 48.0;
    final foreground = switch (variant) {
      HaraButtonVariant.primary => colors.onPrimary,
      _ => colors.foreground,
    };
    final textStyle = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: foreground, fontSize: small ? 14 : 15);

    // The label is announced by the surrounding button semantics.
    final content = ExcludeSemantics(
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: small ? 18 : HaraSizes.iconSmall,
              color: foreground,
            ),
            const SizedBox(width: HaraSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final Widget button;
    if (variant == HaraButtonVariant.ghost) {
      button = Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(HaraRadius.md),
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.md),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      );
    } else {
      button = HaraPressable(
        onPressed: onPressed,
        semanticLabel: label,
        color: variant == HaraButtonVariant.primary
            ? colors.primary
            : colors.surface,
        shadowOffset: enabled ? HaraShadow.offset : 0,
        child: SizedBox(
          height: height - HaraBorder.regular * 2,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: small ? HaraSpacing.md : HaraSpacing.lg,
            ),
            child: Center(widthFactor: expand ? null : 1, child: content),
          ),
        ),
      );
    }

    return Opacity(opacity: enabled ? 1 : 0.45, child: button);
  }
}
