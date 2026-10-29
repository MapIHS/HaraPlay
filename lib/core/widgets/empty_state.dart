import 'package:flutter/material.dart';

import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';
import 'hara_button.dart';
import 'hara_pressable.dart';

/// Centered illustration-free empty state: icon tile, title, message and an
/// optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HaraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HaraPressable(
              color: colors.primary,
              borderRadius: HaraRadius.lg,
              isButton: false,
              child: SizedBox.square(
                dimension: 72,
                child: Icon(icon, size: 32, color: colors.onPrimary),
              ),
            ),
            const SizedBox(height: HaraSpacing.lg),
            Text(
              title,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HaraSpacing.sm),
            Text(
              message,
              style: textTheme.bodyMedium!.copyWith(
                color: colors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: HaraSpacing.xl),
              HaraButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
