import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/artwork/song_artwork.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_icon_button.dart';
import 'player_providers.dart';

/// The docked player above the bottom navigation. Hidden until something
/// has been played. (Expanding into Now Playing arrives in M7.)
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const double artSize = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(playbackStatusProvider).value;
    final song = status?.song;
    if (status == null || song == null) return const SizedBox.shrink();

    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final player = ref.read(playerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaraSpacing.sm,
        0,
        HaraSpacing.sm + HaraShadow.offset,
        HaraSpacing.sm + HaraShadow.offset,
      ),
      child: Semantics(
        container: true,
        label: 'Now playing: ${song.title} by ${song.displayArtist}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(HaraRadius.lg),
            border: Border.all(color: colors.border, width: HaraBorder.regular),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                offset: const Offset(HaraShadow.offset, HaraShadow.offset),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              HaraRadius.lg - HaraBorder.regular,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProgressLine(duration: status.duration),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HaraSpacing.sm,
                    HaraSpacing.sm - 3,
                    HaraSpacing.xs,
                    HaraSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      SongArtwork(
                        songId: song.id,
                        albumId: song.albumId,
                        version: song.version,
                        size: artSize,
                        borderRadius: HaraRadius.sm,
                      ),
                      const SizedBox(width: HaraSpacing.md),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                style: textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song.displayArtist,
                                style: textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      HaraIconButton(
                        icon: status.playing ? HaraIcons.pause : HaraIcons.play,
                        tooltip: status.playing ? 'Pause' : 'Play',
                        variant: HaraIconButtonVariant.primary,
                        size: 44,
                        iconSize: HaraSizes.iconSmall,
                        onPressed: player.togglePlay,
                      ),
                      HaraIconButton(
                        icon: HaraIcons.skipForward,
                        tooltip: 'Next',
                        onPressed: player.next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin line along the top edge; the only part that rebuilds with the
/// playback position.
class _ProgressLine extends ConsumerWidget {
  const _ProgressLine({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = HaraColors.of(context);
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final total = duration.inMilliseconds;
    final fraction = total <= 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: SizedBox(
        height: 3,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: ColoredBox(color: colors.emphasis),
          ),
        ),
      ),
    );
  }
}
