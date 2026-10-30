import 'package:flutter/material.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/widgets/artwork_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_card.dart';
import '../../../core/widgets/hara_chip.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/song_tile.dart';
import '../../settings/presentation/theme_mode_picker.dart';

/// Debug screen showing every design token and core widget in the current
/// theme. Reachable from Settings → Developer in debug builds.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  bool _shuffle = true;
  bool _playing = false;
  int _repeat = 0;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Design gallery')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
        children: [
          const _Padded(child: ThemeModePicker()),
          const SectionHeader(title: 'Colours'),
          _Padded(
            child: Wrap(
              spacing: HaraSpacing.sm,
              runSpacing: HaraSpacing.sm,
              children: [
                _Swatch('background', colors.background),
                _Swatch('surface', colors.surface),
                _Swatch('surfaceAlt', colors.surfaceAlt),
                _Swatch('primary', colors.primary),
                _Swatch('emphasis', colors.emphasis),
                _Swatch('foreground', colors.foreground),
                _Swatch('muted', colors.mutedForeground),
                _Swatch('border', colors.border),
                _Swatch('mint', colors.mint),
                _Swatch('sky', colors.sky),
                _Swatch('lilac', colors.lilac),
                _Swatch('coral', colors.coral),
                _Swatch('danger', colors.danger),
              ],
            ),
          ),
          const SectionHeader(title: 'Typography'),
          _Padded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display 34', style: textTheme.displaySmall),
                Text('Headline 26', style: textTheme.headlineMedium),
                Text('Headline small 22', style: textTheme.headlineSmall),
                Text('Title 20 — Bricolage', style: textTheme.titleLarge),
                Text('Title medium 16 — DM Sans', style: textTheme.titleMedium),
                Text(
                  'Body 15 — The quick brown fox jumps over the lazy dog.',
                  style: textTheme.bodyMedium,
                ),
                Text(
                  'Body small 13 — muted subtitle',
                  style: textTheme.bodySmall,
                ),
                Text('LABEL 12', style: textTheme.labelMedium),
                Text(
                  '3:42  ·  -1:05  ·  128',
                  style: HaraTextStyles.of(context).mono,
                ),
                Text('2020', style: HaraTextStyles.of(context).monoStrong),
              ],
            ),
          ),
          const SectionHeader(title: 'Buttons'),
          _Padded(
            child: Wrap(
              spacing: HaraSpacing.sm,
              runSpacing: HaraSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                HaraButton(
                  label: 'Play',
                  icon: HaraIcons.play,
                  onPressed: () => _snack('Play'),
                ),
                HaraButton(
                  label: 'Shuffle',
                  icon: HaraIcons.shuffle,
                  variant: HaraButtonVariant.secondary,
                  onPressed: () => _snack('Shuffle'),
                ),
                HaraButton(
                  label: 'See all',
                  variant: HaraButtonVariant.ghost,
                  onPressed: () => _snack('See all'),
                ),
                HaraButton(
                  label: 'Small',
                  size: HaraButtonSize.small,
                  onPressed: () => _snack('Small'),
                ),
                const HaraButton(label: 'Disabled', onPressed: null),
                HaraButton(
                  label: 'Full width',
                  expand: true,
                  variant: HaraButtonVariant.secondary,
                  onPressed: () => _snack('Full width'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Transport'),
          _Padded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                HaraIconButton(
                  icon: HaraIcons.shuffle,
                  tooltip: 'Shuffle',
                  selected: _shuffle,
                  onPressed: () => setState(() => _shuffle = !_shuffle),
                ),
                HaraIconButton(
                  icon: HaraIcons.skipBack,
                  tooltip: 'Previous',
                  iconSize: HaraSizes.iconTransport,
                  onPressed: () {},
                ),
                HaraIconButton(
                  icon: _playing ? HaraIcons.pause : HaraIcons.play,
                  tooltip: _playing ? 'Pause' : 'Play',
                  variant: HaraIconButtonVariant.primary,
                  size: 72,
                  iconSize: 32,
                  onPressed: () => setState(() => _playing = !_playing),
                ),
                HaraIconButton(
                  icon: HaraIcons.skipForward,
                  tooltip: 'Next',
                  iconSize: HaraSizes.iconTransport,
                  onPressed: () {},
                ),
                HaraIconButton(
                  icon: _repeat == 2 ? HaraIcons.repeat1 : HaraIcons.repeat,
                  tooltip: const [
                    'Repeat off',
                    'Repeat all',
                    'Repeat one',
                  ][_repeat],
                  selected: _repeat > 0,
                  onPressed: () => setState(() => _repeat = (_repeat + 1) % 3),
                ),
              ],
            ),
          ),
          _Padded(
            child: Wrap(
              spacing: HaraSpacing.sm,
              children: [
                HaraIconButton(
                  icon: HaraIcons.heart,
                  tooltip: 'Like',
                  variant: HaraIconButtonVariant.outline,
                  onPressed: () {},
                ),
                HaraIconButton(
                  icon: HaraIcons.listMusic,
                  tooltip: 'Queue',
                  variant: HaraIconButtonVariant.outline,
                  onPressed: () {},
                ),
                const HaraIconButton(
                  icon: HaraIcons.timer,
                  tooltip: 'Sleep timer (disabled)',
                  variant: HaraIconButtonVariant.outline,
                  onPressed: null,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Chips'),
          _Padded(
            child: Wrap(
              spacing: HaraSpacing.sm,
              runSpacing: HaraSpacing.sm,
              children: [
                const HaraChip(value: '2020', label: 'Year'),
                const HaraChip(value: '12', label: 'Tracks'),
                const HaraChip(value: '48:10', label: 'Total'),
                HaraChip(label: 'Synth-pop', color: colors.lilac),
                HaraChip(label: 'Rock', color: colors.coral),
                HaraChip(
                  label: 'Tappable',
                  icon: HaraIcons.tag,
                  color: colors.mint,
                  onPressed: () => _snack('Chip tapped'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Cards & artwork'),
          _Padded(
            child: HaraCard(
              onTap: () => _snack('Card tapped'),
              child: Row(
                children: [
                  const ArtworkImage(size: 96, seed: 2, shadow: true),
                  const SizedBox(width: HaraSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Album title', style: textTheme.headlineSmall),
                        Text('by Some Artist', style: textTheme.bodySmall),
                        const SizedBox(height: HaraSpacing.sm),
                        const HaraChip(value: '9', label: 'Tracks'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HaraSpacing.md),
          _Padded(
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  ArtworkImage(size: 64, seed: i),
                  const SizedBox(width: HaraSpacing.md),
                ],
              ],
            ),
          ),
          const SectionHeader(title: 'Song tiles', actionLabel: 'See all'),
          SongTile(
            title: 'A song that is playing right now',
            subtitle: 'Artist · Album',
            duration: const Duration(minutes: 3, seconds: 42),
            selected: true,
            leading: const ArtworkImage(
              size: HaraSizes.songTileArtwork,
              seed: 1,
            ),
            onTap: () {},
            onMore: () => _showActionsSheet(context),
          ),
          SongTile(
            title: 'Another song with a much longer title that will be cut off',
            subtitle: 'Another Artist · Another Album',
            duration: const Duration(minutes: 5, seconds: 7),
            leading: const ArtworkImage(
              size: HaraSizes.songTileArtwork,
              seed: 3,
            ),
            onTap: () {},
            onMore: () => _showActionsSheet(context),
          ),
          SongTile(
            title: 'Live recording',
            subtitle: 'Band · Concert',
            duration: const Duration(hours: 1, minutes: 2, seconds: 3),
            leading: const ArtworkImage(
              size: HaraSizes.songTileArtwork,
              seed: 2,
            ),
            onTap: () {},
            onMore: () => _showActionsSheet(context),
          ),
          const SectionHeader(title: 'Sheet & slider'),
          _Padded(
            child: HaraButton(
              label: 'Open song actions sheet',
              variant: HaraButtonVariant.secondary,
              icon: HaraIcons.ellipsis,
              onPressed: () => _showActionsSheet(context),
            ),
          ),
          Slider(value: 0.35, onChanged: (_) {}),
          const SectionHeader(title: 'Empty state'),
          SizedBox(
            height: 300,
            child: EmptyState(
              icon: HaraIcons.music,
              title: 'No music found',
              message: 'Add audio files to your phone, then rescan.',
              actionLabel: 'Rescan',
              onAction: () => _snack('Rescan'),
            ),
          ),
          const SectionHeader(title: 'Icons'),
          _Padded(
            child: Wrap(
              spacing: HaraSpacing.md,
              runSpacing: HaraSpacing.md,
              children: [
                for (final entry in HaraIcons.values.entries)
                  Tooltip(
                    message: entry.key,
                    child: Icon(entry.value, semanticLabel: entry.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showActionsSheet(BuildContext context) {
    showHaraSheet<void>(
      context: context,
      title: 'Song actions',
      builder: (context) => Column(
        children: [
          for (final (icon, label) in const [
            (HaraIcons.listStart, 'Play next'),
            (HaraIcons.listEnd, 'Add to queue'),
            (HaraIcons.listPlus, 'Add to playlist'),
            (HaraIcons.heart, 'Like'),
            (HaraIcons.disc3, 'Go to album'),
            (HaraIcons.user, 'Go to artist'),
            (HaraIcons.info, 'Song info'),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: HaraSpacing.gutter,
      vertical: HaraSpacing.xs,
    ),
    child: child,
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final hex = color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(HaraRadius.sm),
              border: Border.all(color: colors.border, width: HaraBorder.thin),
            ),
          ),
          const SizedBox(height: HaraSpacing.xs),
          Text(name, style: Theme.of(context).textTheme.labelMedium),
          Text('#$hex', style: HaraTextStyles.of(context).mono),
        ],
      ),
    );
  }
}
