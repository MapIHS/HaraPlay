import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../../core/widgets/heart_mark.dart';
import '../../lyrics/presentation/lyrics_providers.dart';
import '../../lyrics/presentation/lyrics_view.dart';
import '../../playlists/presentation/playlist_providers.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';
import 'queue_sheet.dart';
import 'seek_bar.dart';
import 'sleep_timer_sheet.dart';
import 'song_actions_sheet.dart';

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
  return switch (status.source) {
    _ when label == null => kind,
    // Home rows ("Recently played") name themselves.
    PlaySource.songs => label,
    PlaySource.search => '$kind · "$label"',
    _ => '$kind · $label',
  };
}

/// The artwork / lyrics area, measured when lyrics are switched on.
final _artworkAreaKey = GlobalKey(debugLabel: 'now-playing-artwork');

/// Below this height (very large text on a small phone) the lyrics panel
/// would be unreadable, so the lyrics open full screen instead.
const _minLyricsPanelHeight = 120.0;

void _toggleLyrics(BuildContext context, WidgetRef ref, QueueSong song) {
  final showing = ref.read(showLyricsProvider);
  final height = _artworkAreaKey.currentContext?.size?.height ?? 0;
  if (!showing && height < _minLyricsPanelHeight) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => LyricsScreen(song: song)));
    return;
  }
  ref.read(showLyricsProvider.notifier).toggle();
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
                HaraIconButton(
                  icon: HaraIcons.ellipsisVertical,
                  tooltip: 'Song actions',
                  onPressed: () => showSongActions(
                    context,
                    ref,
                    song,
                    beforeNavigate: onCollapse,
                    // A snackbar would sit behind the player.
                    showFeedback: false,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              key: _artworkAreaKey,
              padding: const EdgeInsets.fromLTRB(
                HaraSpacing.xl,
                HaraSpacing.lg,
                HaraSpacing.xl,
                HaraSpacing.lg,
              ),
              child: ref.watch(showLyricsProvider)
                  ? LyricsPanel(song: song)
                  : Center(child: _SwipeableArtwork(song: song)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: HaraSpacing.xl,
              right: HaraSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TitleBlock(song: song, onCollapse: onCollapse),
                ),
                const SizedBox(width: HaraSpacing.sm),
                LikeButton(
                  liked: ref.watch(isLikedProvider(song.id)),
                  onPressed: () => setLiked(
                    ref,
                    song.id,
                    liked: !ref.read(isLikedProvider(song.id)),
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
          const SizedBox(height: HaraSpacing.sm),
          // Bottom actions on one line: sleep timer, the queue, lyrics.
          // The queue label gives way first if space runs out.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(child: SleepTimerButton()),
                const SizedBox(width: HaraSpacing.xs),
                Flexible(
                  flex: 2,
                  child: HaraButton(
                    label: 'Up next · ${status.upcomingCount}',
                    icon: HaraIcons.listMusic,
                    variant: HaraButtonVariant.ghost,
                    size: HaraButtonSize.small,
                    onPressed: () => showQueueSheet(context),
                  ),
                ),
                const SizedBox(width: HaraSpacing.xs),
                HaraIconButton(
                  icon: HaraIcons.micVocal,
                  tooltip: ref.watch(showLyricsProvider)
                      ? 'Hide lyrics'
                      : 'Lyrics',
                  selected: ref.watch(showLyricsProvider),
                  onPressed: () => _toggleLyrics(context, ref, song),
                ),
              ],
            ),
          ),
          const SizedBox(height: HaraSpacing.sm),
        ],
      ),
    );
  }
}

/// Title and the artist link.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.song, required this.onCollapse});

  final QueueSong song;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
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
              final router = GoRouter.of(context);
              router.push(
                AppRoutes.artist(song.artist, tab: currentTab(router)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: HaraSpacing.xs),
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
