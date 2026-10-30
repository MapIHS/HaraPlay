import 'package:flutter/material.dart';

import '../../../../core/icons/hara_icons.dart';
import '../../../../core/theme/hara_colors.dart';
import '../../../../core/theme/hara_tokens.dart';
import '../../../../core/widgets/hara_pressable.dart';

/// A 64dp browse row (artist, folder, genre): leading visual, title,
/// subtitle and a chevron.
class LibraryRow extends StatelessWidget {
  const LibraryRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const double height = 64;

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
            child: Row(
              children: [
                leading,
                const SizedBox(width: HaraSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  HaraIcons.chevronRight,
                  size: HaraSizes.iconSmall,
                  color: colors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bordered square with an icon on a pastel accent, for things that have
/// no artwork (folders, genres).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.seed,
    this.size = HaraSizes.songTileArtwork,
    this.shadow = false,
  });

  final IconData icon;

  /// Picks the accent colour, so the same name always gets the same colour.
  final int seed;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final tile = SizedBox.square(
      dimension: size,
      child: Icon(icon, size: size * 0.42, color: colors.foreground),
    );
    return ExcludeSemantics(
      child: HaraPressable(
        isButton: false,
        color: colors.accents[seed.abs() % colors.accents.length],
        borderRadius: size >= 120 ? HaraRadius.lg : HaraRadius.md,
        borderWidth: size >= 120 ? HaraBorder.regular : HaraBorder.thin,
        shadowOffset: shadow ? HaraShadow.offset : 0,
        child: tile,
      ),
    );
  }
}

/// A stable small hash for picking accent colours from text.
int stableSeed(String text) =>
    text.codeUnits.fold(0, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);
