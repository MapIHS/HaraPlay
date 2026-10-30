import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_button.dart';
import 'theme_mode_controller.dart';

/// System / Light / Dark segmented choice bound to [themeModeProvider].
class ThemeModePicker extends ConsumerWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    return Row(
      children: [
        for (final (value, icon, label) in const [
          (ThemeMode.system, HaraIcons.sunMoon, 'System'),
          (ThemeMode.light, HaraIcons.sun, 'Light'),
          (ThemeMode.dark, HaraIcons.moon, 'Dark'),
        ]) ...[
          Expanded(
            child: Semantics(
              selected: mode == value,
              child: HaraButton(
                label: label,
                icon: icon,
                expand: true,
                size: HaraButtonSize.small,
                variant: mode == value
                    ? HaraButtonVariant.primary
                    : HaraButtonVariant.secondary,
                onPressed: () => controller.setThemeMode(value),
              ),
            ),
          ),
          if (value != ThemeMode.dark) const SizedBox(width: HaraSpacing.xs),
        ],
      ],
    );
  }
}
