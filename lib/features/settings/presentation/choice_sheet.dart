import 'package:flutter/material.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';

/// A settings sheet body: a short explanation, then one row per option
/// with a check on the current one. Choosing closes the sheet.
class ChoiceSheet<T> extends StatelessWidget {
  const ChoiceSheet({
    super.key,
    required this.intro,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.description,
  });

  final String intro;
  final List<T> options;
  final T selected;
  final String Function(T option) label;

  /// An optional second line under an option's label.
  final String? Function(T option)? description;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HaraSpacing.gutter,
            0,
            HaraSpacing.gutter,
            HaraSpacing.sm,
          ),
          child: Text(
            intro,
            style: textTheme.bodyMedium!.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ),
        for (final option in options)
          Semantics(
            selected: option == selected,
            inMutuallyExclusiveGroup: true,
            child: InkWell(
              onTap: () {
                onSelected(option);
                Navigator.of(context).pop();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HaraSpacing.gutter,
                    vertical: HaraSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label(option), style: textTheme.bodyLarge),
                            if (description?.call(option) case final text?)
                              Text(
                                text,
                                style: textTheme.bodySmall!.copyWith(
                                  color: colors.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (option == selected)
                        Icon(HaraIcons.check, color: colors.foreground),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: HaraSpacing.lg),
      ],
    );
  }
}
