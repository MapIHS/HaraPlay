import 'package:flutter/material.dart';

import '../icons/hara_icons.dart';
import '../theme/hara_colors.dart';
import '../theme/hara_tokens.dart';
import '../theme/hara_typography.dart';
import '../utils/duration_format.dart';
import 'hara_icon_button.dart';
import 'heart_mark.dart';

/// A 64dp song row: artwork, title/subtitle, duration and a "more" button.
///
/// [selected] marks the currently playing song with a highlighted row and a
/// brand-coloured bar on its leading edge; [liked] adds a small heart.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.duration,
    this.selected = false,
    this.liked = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.trailing,
  });

  final String title;
  final String subtitle;

  /// Usually an [ArtworkImage] of [HaraSizes.songTileArtwork].
  final Widget? leading;
  final Duration? duration;
  final bool selected;
  final bool liked;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  /// After the "more" button, e.g. a drag handle.
  final Widget? trailing;

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
      // The trailing widget sits outside the ink well, so holding a drag
      // handle never counts as a long-press on the row.
      child: Row(
        children: [
          Expanded(child: _body(context, colors, textTheme, titleStyle)),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: HaraSpacing.xs),
          ],
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    HaraColors colors,
    TextTheme textTheme,
    TextStyle titleStyle,
  ) => InkWell(
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
            if (liked) ...[
              const SizedBox(width: HaraSpacing.sm),
              const HeartMark(size: 14, semanticLabel: 'Liked'),
            ],
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
            else if (trailing == null)
              const SizedBox(width: HaraSpacing.md),
          ],
        ),
      ),
    ),
  );
}
