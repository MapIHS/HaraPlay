import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/artwork/song_artwork.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';

/// The docked player card: tap (or drag up, see `PlayerPanel`) to expand,
/// swipe sideways for the next / previous song.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.status, this.onTap});

  static const double artSize = 44;

  /// The card itself, border included.
  static const double cardHeight = 64;

  /// Space the docked card takes above the bottom navigation: the card, its
  /// hard shadow and the gap below it.
  static const double dockHeight =
      cardHeight + HaraSpacing.sm + HaraShadow.offset;

  /// Horizontal fling speed (logical px/s) that skips a song.
  static const double swipeVelocity = 350;

  final PlaybackStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = status.song!;
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
        button: true,
        label: 'Now playing: ${song.title} by ${song.displayArtist}',
        hint: 'Opens the player',
        onTap: onTap,
        // The swipe as named actions; the gesture itself would add an
        // unlabelled node to the tree.
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Next song'): player.next,
          const CustomSemanticsAction(label: 'Previous song'): player.previous,
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: onTap,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity <= -swipeVelocity) player.next();
            if (velocity >= swipeVelocity) player.previous();
          },
          child: Container(
            height: cardHeight,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(HaraRadius.lg),
              border: Border.all(
                color: colors.border,
                width: HaraBorder.regular,
              ),
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
                children: [
                  _ProgressLine(duration: status.duration),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: HaraSpacing.sm,
                        right: HaraSpacing.xs,
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    song.title,
                                    style: textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // With very large text the card is too
                                  // short for two lines; the artist then
                                  // gives way to the title (it is still in
                                  // the semantics label).
                                  Flexible(
                                    child: ClipRect(
                                      child: Text(
                                        song.displayArtist,
                                        style: textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          HaraIconButton(
                            icon: status.playing
                                ? HaraIcons.pause
                                : HaraIcons.play,
                            tooltip: status.playing ? 'Pause' : 'Play',
                            variant: HaraIconButtonVariant.primary,
                            size: HaraSizes.minTouchTarget,
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
                  ),
                ],
              ),
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
