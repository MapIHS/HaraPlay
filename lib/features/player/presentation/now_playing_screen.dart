import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';
import 'seek_bar.dart';

/// "Playing from …" text for the top bar.
String playingFrom(PlaybackStatus status) {
  final kind = switch (status.source) {
    PlaySource.songs => 'All songs',
    PlaySource.album => 'Album',
    PlaySource.artist => 'Artist',
    PlaySource.folder => 'Folder',
    PlaySource.genre => 'Genre',
    PlaySource.playlist => 'Playlist',
    PlaySource.favorites => 'Liked songs',
    PlaySource.search => 'Search',
    PlaySource.queue => 'Your queue',
    PlaySource.external => 'A shared file',
  };
  final label = status.sourceLabel;
  return label == null || status.source == PlaySource.songs
      ? kind
      : '$kind · $label';
}

/// The full player inside the expanded `PlayerPanel`.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key, required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(playbackStatusProvider).value;
    final song = status?.song;
    if (status == null || song == null) return const SizedBox.shrink();
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        // Stretch, so the title block lines up with the left edge.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: collapse, "Playing from", balanced spacer.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.xs),
            child: Row(
              children: [
                HaraIconButton(
                  icon: HaraIcons.chevronDown,
                  tooltip: 'Close player',
                  onPressed: onCollapse,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('PLAYING FROM', style: textTheme.labelSmall),
                      Text(
                        playingFrom(status),
                        style: textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HaraSizes.minTouchTarget),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HaraSpacing.xl,
                HaraSpacing.lg,
                HaraSpacing.xl,
                HaraSpacing.lg,
              ),
              child: Center(child: _SwipeableArtwork(song: song)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    song.title,
                    style: textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: HaraSpacing.xs),
                Semantics(
                  link: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(HaraRadius.sm),
                    onTap: () {
                      onCollapse();
                      context.push(AppRoutes.artist(song.artist));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: HaraSpacing.xs,
                      ),
                      child: Text(
                        song.displayArtist,
                        style: textTheme.bodyLarge!.copyWith(
                          color: colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HaraSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.sm),
            child: SeekBar(duration: status.duration),
          ),
          const SizedBox(height: HaraSpacing.md),
          _TransportControls(status: status),
          const SizedBox(height: HaraSpacing.xl),
        ],
      ),
    );
  }
}

/// Large artwork that can be swiped sideways for the next / previous song.
class _SwipeableArtwork extends ConsumerStatefulWidget {
  const _SwipeableArtwork({required this.song});

  final QueueSong song;

  @override
  ConsumerState<_SwipeableArtwork> createState() => _SwipeableArtworkState();
}

class _SwipeableArtworkState extends ConsumerState<_SwipeableArtwork> {
  double _dx = 0;

  void _onEnd(DragEndDetails details, double size) {
    final velocity = details.primaryVelocity ?? 0;
    final player = ref.read(playerProvider);
    if (_dx < -size / 4 || velocity < -500) {
      player.next();
    } else if (_dx > size / 4 || velocity > 500) {
      player.previous();
    }
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final song = widget.song;
        return Semantics(
          image: true,
          label:
              'Artwork. Swipe left for the next song, right for the '
              'previous one.',
          child: GestureDetector(
            onHorizontalDragUpdate: (d) =>
                setState(() => _dx += d.primaryDelta ?? 0),
            onHorizontalDragEnd: (d) => _onEnd(d, size),
            child: AnimatedContainer(
              duration: _dx == 0 ? HaraMotion.medium : Duration.zero,
              curve: HaraMotion.emphasized,
              transform: Matrix4.translationValues(_dx, 0, 0),
              child: SongArtwork(
                key: ValueKey(song.id),
                songId: song.id,
                albumId: song.albumId,
                version: song.version,
                size: size - HaraShadow.offset,
                shadow: true,
                borderRadius: HaraRadius.xl,
                borderWidth: HaraBorder.regular,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.status});

  final PlaybackStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final repeat = status.repeat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HaraIconButton(
            icon: HaraIcons.shuffle,
            tooltip: status.shuffle ? 'Shuffle on' : 'Shuffle off',
            selected: status.shuffle,
            onPressed: () => player.setShuffle(!status.shuffle),
          ),
          HaraIconButton(
            icon: HaraIcons.skipBack,
            tooltip: 'Previous',
            size: 56,
            iconSize: HaraSizes.iconTransport,
            onPressed: player.previous,
          ),
          HaraIconButton(
            icon: status.playing ? HaraIcons.pause : HaraIcons.play,
            tooltip: status.playing ? 'Pause' : 'Play',
            variant: HaraIconButtonVariant.primary,
            size: 72,
            iconSize: HaraSizes.iconTransport,
            onPressed: player.togglePlay,
          ),
          HaraIconButton(
            icon: HaraIcons.skipForward,
            tooltip: 'Next',
            size: 56,
            iconSize: HaraSizes.iconTransport,
            onPressed: player.next,
          ),
          HaraIconButton(
            icon: repeat == RepeatSetting.one
                ? HaraIcons.repeat1
                : HaraIcons.repeat,
            tooltip: switch (repeat) {
              RepeatSetting.off => 'Repeat off',
              RepeatSetting.all => 'Repeat all',
              RepeatSetting.one => 'Repeat one',
            },
            selected: repeat != RepeatSetting.off,
            onPressed: () => player.setRepeat(switch (repeat) {
              RepeatSetting.off => RepeatSetting.all,
              RepeatSetting.all => RepeatSetting.one,
              RepeatSetting.one => RepeatSetting.off,
            }),
          ),
        ],
      ),
    );
  }
}
