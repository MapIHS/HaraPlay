import 'package:flutter/material.dart';

import '../../../../core/icons/hara_icons.dart';
import '../../../../core/theme/hara_colors.dart';
import '../../../../core/theme/hara_tokens.dart';
import '../../../../core/widgets/hara_button.dart';
import '../../../../core/widgets/hara_chip.dart';

/// Hero header of the album / artist / folder / genre screens: large
/// visual with a hard shadow, headline, a muted subtitle line, stat chips
/// and the Play / Shuffle buttons.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.visual,
    required this.title,
    required this.chips,
    required this.onPlay,
    required this.onShuffle,
    this.kicker,
    this.subtitle,
    this.onSubtitleTap,
  });

  static const double visualSize = 168;

  final Widget visual;

  /// Small uppercase label above the title ("ALBUM", "FOLDER").
  final String? kicker;
  final String title;
  final String? subtitle;

  /// Makes the subtitle a link (album → artist).
  final VoidCallback? onSubtitleTap;
  final List<HaraChip> chips;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final subtitleText = subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaraSpacing.gutter,
        HaraSpacing.sm,
        HaraSpacing.gutter,
        HaraSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          visual,
          const SizedBox(height: HaraSpacing.lg),
          if (kicker != null)
            Text(
              kicker!.toUpperCase(),
              style: textTheme.labelMedium!.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: textTheme.headlineMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitleText != null) ...[
            const SizedBox(height: HaraSpacing.xs),
            _Subtitle(text: subtitleText, onTap: onSubtitleTap),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: HaraSpacing.md),
            Wrap(
              spacing: HaraSpacing.sm,
              runSpacing: HaraSpacing.sm,
              children: chips,
            ),
          ],
          const SizedBox(height: HaraSpacing.lg),
          Row(
            children: [
              Expanded(
                child: HaraButton(
                  label: 'Play',
                  icon: HaraIcons.play,
                  expand: true,
                  onPressed: onPlay,
                ),
              ),
              const SizedBox(width: HaraSpacing.sm),
              Expanded(
                child: HaraButton(
                  label: 'Shuffle',
                  icon: HaraIcons.shuffle,
                  variant: HaraButtonVariant.secondary,
                  expand: true,
                  onPressed: onShuffle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final style = Theme.of(context).textTheme.bodyLarge!
        .copyWith(color: colors.mutedForeground);
    final label = Text(
      text,
      style: onTap == null
          ? style
          : style.copyWith(
              color: colors.foreground,
              decoration: TextDecoration.underline,
              decorationColor: colors.emphasis,
              decorationThickness: 2,
            ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    if (onTap == null) return label;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HaraRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: HaraSpacing.xs),
          child: label,
        ),
      ),
    );
  }
}
