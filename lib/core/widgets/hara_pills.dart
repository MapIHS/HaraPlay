import 'package:flutter/material.dart';

import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';

/// A bordered pill; brand fill with a hard shadow when [selected].
class HaraPill extends StatelessWidget {
  const HaraPill({super.key, required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.lg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(HaraRadius.pill),
        border: Border.all(color: colors.border, width: HaraBorder.thin),
        boxShadow: [
          BoxShadow(
            color: selected ? colors.shadow : Colors.transparent,
            offset: const Offset(HaraShadow.small, HaraShadow.small),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge!
            .copyWith(color: selected ? colors.onPrimary : colors.foreground),
      ),
    );
  }
}

/// A scrollable row of pill tabs for a [DefaultTabController] (Library,
/// Stats).
class HaraPillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const HaraPillTabBar({super.key, required this.titles});

  final List<String> titles;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.fromLTRB(
          HaraSpacing.gutter - HaraSpacing.xs,
          HaraSpacing.xs,
          HaraSpacing.gutter,
          HaraSpacing.md,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: HaraSpacing.xs),
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        indicator: const BoxDecoration(),
        tabs: [
          for (final (index, title) in titles.indexed)
            _PillTab(index: index, title: title),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({required this.index, required this.title});

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) =>
          HaraPill(label: title, selected: controller.index == index),
    );
  }
}

/// One choice out of a few, as a row of pills (e.g. a time range).
class HaraPillChoice<T> extends StatelessWidget {
  const HaraPillChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        HaraSpacing.gutter,
        HaraSpacing.xs,
        HaraSpacing.gutter,
        HaraSpacing.sm,
      ),
      child: Row(
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(right: HaraSpacing.sm),
              child: Semantics(
                button: true,
                selected: value == selected,
                label: label(value),
                excludeSemantics: true,
                onTap: () => onChanged(value),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  // 48 dp touch target around the 36 dp pill.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: HaraSpacing.xs + 2,
                    ),
                    child: HaraPill(
                      label: label(value),
                      selected: value == selected,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
