import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/palettes.dart';
import 'color_choice_controller.dart';

/// A row of colour swatches: the three brand palettes, plus "Wallpaper"
/// when the system offers wallpaper colours (Android 12+).
class ColorChoicePicker extends ConsumerWidget {
  const ColorChoicePicker({super.key});

  static const double swatchHeight = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(colorChoiceProvider);
    final tones = ref.watch(systemTonesProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final choices = [
      for (final choice in ColorChoice.values)
        if (choice != ColorChoice.wallpaper || tones != null) choice,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, choice) in choices.indexed) ...[
          if (i > 0) const SizedBox(width: HaraSpacing.sm),
          Expanded(
            child: _Swatch(
              label: choice.label,
              palette: dark
                  ? HaraPalettes.of(choice, tones).$2
                  : HaraPalettes.of(choice, tones).$1,
              selected: choice == selected,
              onTap: () => ref.read(colorChoiceProvider.notifier).set(choice),
            ),
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final HaraColors palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label colours',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HaraRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: HaraSpacing.xs),
          child: Column(
            children: [
              // The palette's page with its fill colour on top: shows both
              // the background tint and the accent.
              Container(
                height: ColorChoicePicker.swatchHeight,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(HaraRadius.md),
                  border: Border.all(
                    color: colors.border,
                    width: selected ? HaraBorder.regular + 1 : HaraBorder.thin,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: colors.shadow,
                            offset: const Offset(
                              HaraShadow.offset,
                              HaraShadow.offset,
                            ),
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(HaraSpacing.sm),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(HaraRadius.sm),
                    border: Border.all(
                      color: palette.border,
                      width: HaraBorder.thin,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Icon(
                          HaraIcons.check,
                          size: HaraSizes.iconSmall,
                          color: palette.onPrimary,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: HaraSpacing.xs),
              Text(
                label,
                style: textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
