import 'package:flutter/material.dart';

import '../../../../core/icons/hara_icons.dart';
import '../../../../core/theme/hara_colors.dart';
import '../../../../core/theme/hara_tokens.dart';
import '../../../../core/widgets/hara_button.dart';
import '../../../../core/widgets/hara_sheet.dart';
import '../../domain/library_sort.dart';

/// Shows a sheet to pick a sort field and direction. Returns the new sort,
/// or null if dismissed.
Future<LibrarySort<F>?> showSortSheet<F extends Enum>({
  required BuildContext context,
  required LibrarySort<F> current,
  required Map<F, String> labels,
}) => showHaraSheet<LibrarySort<F>>(
  context: context,
  title: 'Sort by',
  builder: (_) => _SortSheet(current: current, labels: labels),
);

/// Tapping a direction or a field applies it and closes the sheet.
class _SortSheet<F extends Enum> extends StatelessWidget {
  const _SortSheet({required this.current, required this.labels});

  final LibrarySort<F> current;
  final Map<F, String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    void choose(LibrarySort<F> sort) => Navigator.of(context).pop(sort);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
          child: Row(
            children: [
              for (final (descending, label) in const [
                (false, 'Ascending'),
                (true, 'Descending'),
              ]) ...[
                Expanded(
                  child: Semantics(
                    selected: current.descending == descending,
                    child: HaraButton(
                      label: label,
                      size: HaraButtonSize.small,
                      expand: true,
                      variant: current.descending == descending
                          ? HaraButtonVariant.primary
                          : HaraButtonVariant.secondary,
                      onPressed: () =>
                          choose(current.copyWith(descending: descending)),
                    ),
                  ),
                ),
                if (!descending) const SizedBox(width: HaraSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: HaraSpacing.sm),
        for (final MapEntry(key: field, value: label) in labels.entries)
          Semantics(
            selected: field == current.field,
            inMutuallyExclusiveGroup: true,
            child: InkWell(
              onTap: () => choose(current.copyWith(field: field)),
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HaraSpacing.gutter,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: textTheme.bodyLarge)),
                      if (field == current.field)
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
