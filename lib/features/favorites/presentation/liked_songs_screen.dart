import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_pressable.dart';
import '../../../core/widgets/heart_mark.dart';
import '../../library/presentation/widgets/detail_header.dart';
import '../../library/presentation/widgets/detail_scaffold.dart';
import '../../library/presentation/widgets/library_song_tile.dart';
import '../../player/presentation/play_actions.dart';
import '../../playlists/presentation/playlist_providers.dart';

/// Liked songs, most recently liked first.
class LikedSongsScreen extends ConsumerWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(likedSongsProvider);
    return Scaffold(
      appBar: AppBar(),
      body: switch (songs) {
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: HaraIcons.heart,
          title: 'No liked songs yet',
          message:
              'Tap the heart in the player, or use "Add to Liked songs" in '
              'any song’s ⋮ menu.',
        ),
        AsyncData(:final value) => _LikedList(songs: value),
        AsyncError() => const EmptyState(
          icon: HaraIcons.circleAlert,
          title: "Couldn't load your liked songs",
          message: 'Something went wrong reading the music database.',
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _LikedList extends ConsumerWidget {
  const _LikedList({required this.songs});

  final List<SongRow> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = HaraColors.of(context);
    void play({int index = 0}) =>
        playSongs(ref, songs, index: index, source: PlaySource.favorites);

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DetailHeader(
              visual: HaraPressable(
                isButton: false,
                color: colors.primary,
                borderRadius: HaraRadius.lg,
                borderWidth: HaraBorder.regular,
                shadowOffset: HaraShadow.offset,
                child: SizedBox.square(
                  dimension: DetailHeader.visualSize,
                  child: Center(
                    child: HeartMark(size: 72, fill: colors.surface),
                  ),
                ),
              ),
              title: 'Liked songs',
              chips: countChips(songs),
              onPlay: play,
              onShuffle: () =>
                  shuffleSongs(ref, songs, source: PlaySource.favorites),
            ),
          ),
          SliverList.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) => SizedBox(
              height: HaraSizes.songTileHeight,
              child: LibrarySongTile(
                song: songs[i],
                onTap: () => play(index: i),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: HaraSpacing.xxxl)),
        ],
      ),
    );
  }
}
