import 'package:flutter/material.dart';

import '../icons/hara_icons.dart';
import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';
import '../theme/hara_typography.dart';
import '../utils/duration_format.dart';
import 'hara_icon_button.dart';

/// A 64dp song row: artwork, title/subtitle, duration and a "more" button.
///
/// [selected] marks the currently playing song with a highlighted row and a
/// brand-coloured bar on its leading edge.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.duration,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
  });

  final String title;
  final String subtitle;

  /// Usually an [ArtworkImage] of [HaraSizes.songTileArtwork].
  final Widget? leading;
  final Duration? duration;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = selected
        ? HaraTypography.withWeight(textTheme.titleMedium!, FontWeight.w800)
        : textTheme.titleMedium!;

    return Material(
      color: selected ? colors.surfaceAlt : Colors.transparent,
      shape: selected
          ? Border(left: BorderSide(color: colors.primary, width: 4))
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: HaraSizes.songTileHeight,
          child: Padding(
            padding: const EdgeInsets.only(
              left: HaraSpacing.gutter,
              right: HaraSpacing.xs,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: HaraSpacing.md),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (selected) ...[
                            Icon(
                              HaraIcons.audioLines,
                              size: 16,
                              color: colors.foreground,
                              semanticLabel: 'Now playing',
                            ),
                            const SizedBox(width: HaraSpacing.xs + 2),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                if (duration != null) ...[
                  const SizedBox(width: HaraSpacing.sm),
                  Text(
                    formatDuration(duration!),
                    style: HaraTextStyles.of(context).mono,
                  ),
                ],
                if (onMore != null)
                  HaraIconButton(
                    icon: HaraIcons.ellipsisVertical,
                    tooltip: 'More options',
                    onPressed: onMore,
                    iconSize: HaraSizes.iconSmall,
                  )
                else
                  const SizedBox(width: HaraSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
