import 'package:flutter/material.dart';

import '../theme/hara_tokens.dart';
import 'hara_pressable.dart';

/// The standard bordered card with a hard shadow. Presses in when tappable.
class HaraCard extends StatelessWidget {
  const HaraCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.padding = const EdgeInsets.all(HaraSpacing.lg),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return HaraPressable(
      onPressed: onTap,
      onLongPress: onLongPress,
      color: color,
      borderRadius: HaraRadius.lg,
      padding: padding,
      semanticLabel: semanticLabel,
      isButton: onTap != null,
      child: child,
    );
  }
}
