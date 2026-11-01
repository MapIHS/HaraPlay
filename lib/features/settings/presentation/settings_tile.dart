import 'package:flutter/material.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';

/// A tappable settings row: icon, title, optional subtitle and a chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Shown instead of the chevron (e.g. a switch).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HaraSpacing.gutter,
            vertical: HaraSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: HaraSizes.iconSmall, color: colors.foreground),
              const SizedBox(width: HaraSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  HaraIcons.chevronRight,
                  size: HaraSizes.iconSmall,
                  color: colors.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
