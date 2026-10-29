import 'package:flutter/material.dart';

import '../theme/hara_tokens.dart';
import 'hara_button.dart';

/// A section title with an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (actionLabel != null)
              HaraButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: HaraButtonVariant.ghost,
                size: HaraButtonSize.small,
              ),
          ],
        ),
      ),
    );
  }
}
