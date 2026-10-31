import 'package:flutter/material.dart';

import '../theme/hara_tokens.dart';
import 'hara_button.dart';

/// Cancel and confirm side by side, sharing the dialog's width (the default
/// action bar stacks them on narrow phones). Use with
/// `actionsPadding: HaraDialogActions.padding`.
class HaraDialogActions extends StatelessWidget {
  const HaraDialogActions({
    super.key,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  static const padding = EdgeInsets.fromLTRB(
    HaraSpacing.xl,
    0,
    HaraSpacing.xl,
    HaraSpacing.xl,
  );

  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: Row(
        children: [
          Expanded(
            child: HaraButton(
              label: 'Cancel',
              variant: HaraButtonVariant.secondary,
              expand: true,
              onPressed: onCancel,
            ),
          ),
          const SizedBox(width: HaraSpacing.sm),
          Expanded(
            child: HaraButton(
              label: confirmLabel,
              expand: true,
              onPressed: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}
