import 'package:flutter/material.dart';

import '../../core/icons/hara_icons.dart';
import '../../core/theme/hara_colors.dart';
import '../../core/theme/hara_tokens.dart';
import '../../core/theme/hara_typography.dart';

/// One bottom-nav destination.
typedef HaraNavDestination = ({IconData icon, String label});

/// The four tabs, in branch order (see `router.dart`).
const haraNavDestinations = <HaraNavDestination>[
  (icon: HaraIcons.house, label: 'Home'),
  (icon: HaraIcons.library, label: 'Library'),
  (icon: HaraIcons.search, label: 'Search'),
  (icon: HaraIcons.listMusic, label: 'Playlists'),
];

/// Bottom navigation: a bordered bar where the selected tab sits in a
/// brand-coloured pill with a small hard shadow.
class HaraBottomNav extends StatelessWidget {
  const HaraBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  static const double height = 68;

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: HaraBorder.regular),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < haraNavDestinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: haraNavDestinations[i],
                    selected: i == currentIndex,
                    position: i,
                    count: haraNavDestinations.length,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.position,
    required this.count,
    required this.onTap,
  });

  final HaraNavDestination destination;
  final bool selected;
  final int position;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final labelStyle = Theme.of(context).textTheme.labelMedium!;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final duration = animate ? HaraMotion.fast : Duration.zero;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: destination.label,
      hint: 'Tab ${position + 1} of $count',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: HaraMotion.emphasized,
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(HaraRadius.pill),
                border: Border.all(
                  color: selected ? colors.border : Colors.transparent,
                  width: HaraBorder.thin,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected ? colors.shadow : Colors.transparent,
                    offset: const Offset(HaraShadow.small, HaraShadow.small),
                  ),
                ],
              ),
              child: Icon(
                destination.icon,
                size: HaraSizes.icon,
                color: selected ? colors.onPrimary : colors.mutedForeground,
              ),
            ),
            const SizedBox(height: HaraSpacing.xs),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selected
                  ? HaraTypography.withWeight(
                      labelStyle,
                      FontWeight.w800,
                    ).copyWith(color: colors.foreground)
                  : labelStyle.copyWith(color: colors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
