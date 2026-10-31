import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/library_dao.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_chip.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/widgets/album_card.dart';
import '../../library/presentation/widgets/library_song_tile.dart';
import '../../player/presentation/play_actions.dart';
import '../../playlists/presentation/playlist_providers.dart';
import '../../playlists/presentation/playlists_screen.dart';
import 'home_providers.dart';

/// Home tab: library summary, Shuffle all, Liked songs, then Recently
/// played, Most played and Recently added.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const double cardWidth = 136;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(libraryCountsProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HaraPlay'),
        actions: [
          HaraIconButton(
            icon: HaraIcons.settings,
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(width: HaraSpacing.xs),
        ],
      ),
      body: switch (counts) {
        null => const Center(child: CircularProgressIndicator()),
        LibraryCounts(songs: 0) => EmptyState(
          icon: HaraIcons.house,
          title: 'Welcome to HaraPlay',
          message:
              'No music found yet. Copy audio files to this phone, then '
              'scan again from the Library.',
          actionLabel: 'Open Library',
          onAction: () => context.go(AppRoutes.library),
        ),
        final counts => _HomeContent(counts: counts),
      },
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.counts});

  final LibraryCounts counts;

  Future<void> _shuffleAll(WidgetRef ref) async {
    // A one-off read: an unlistened provider would stay paused.
    final songs = await ref
        .read(browseDaoProvider)
        .watchSongs(
          ref.read(songSortProvider),
          minDurationMs: ref.read(minDurationMsProvider),
        )
        .first;
    if (songs.isEmpty) return;
    await shuffleSongs(ref, songs, source: PlaySource.songs);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedCount = ref.watch(
      likedSongIdsProvider.select((ids) => ids.value?.length ?? 0),
    );
    final hours = counts.totalDuration.inMinutes / 60;

    return ListView(
      padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HaraSpacing.gutter,
            HaraSpacing.xs,
            HaraSpacing.gutter,
            0,
          ),
          child: Wrap(
            spacing: HaraSpacing.sm,
            runSpacing: HaraSpacing.sm,
            children: [
              HaraChip(
                value: '${counts.songs}',
                label: counts.songs == 1 ? 'Song' : 'Songs',
              ),
              HaraChip(
                value: '${counts.albums}',
                label: counts.albums == 1 ? 'Album' : 'Albums',
              ),
              HaraChip(
                value: hours >= 1
                    ? hours.toStringAsFixed(hours >= 10 ? 0 : 1)
                    : formatTotalDuration(counts.totalDuration),
                label: hours >= 1 ? 'Hours' : 'Total',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HaraSpacing.gutter,
            HaraSpacing.lg,
            HaraSpacing.gutter,
            HaraSpacing.md,
          ),
          child: HaraButton(
            label: 'Shuffle all',
            icon: HaraIcons.shuffle,
            expand: true,
            onPressed: () => _shuffleAll(ref),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
          child: LikedSongsCard(
            count: likedCount,
            onTap: () => context.push(AppRoutes.likedSongs),
          ),
        ),
        const SizedBox(height: HaraSpacing.lg),
        const SectionHeader(title: 'Recently played'),
        const _RecentlyPlayedRow(),
        const SizedBox(height: HaraSpacing.lg),
        const SectionHeader(title: 'Most played'),
        const _MostPlayedList(),
        const SizedBox(height: HaraSpacing.lg),
        const SectionHeader(title: 'Recently added'),
        const _RecentlyAddedRow(),
      ],
    );
  }
}

/// A friendly placeholder for a row that has nothing yet.
class _RowHint extends StatelessWidget {
  const _RowHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(HaraRadius.lg),
          border: Border.all(color: colors.border, width: HaraBorder.thin),
        ),
        child: Padding(
          padding: const EdgeInsets.all(HaraSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: HaraSizes.icon, color: colors.mutedForeground),
              const SizedBox(width: HaraSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(color: colors.mutedForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Height of a horizontal card row: artwork, shadow room and two text lines.
const double _cardRowHeight =
    HomeScreen.cardWidth + HaraShadow.offset + HaraSpacing.sm + 44;

class _RecentlyPlayedRow extends ConsumerWidget {
  const _RecentlyPlayedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(recentlyPlayedProvider).value;
    if (songs == null) return const SizedBox(height: _cardRowHeight);
    if (songs.isEmpty) {
      return const _RowHint(
        icon: HaraIcons.history,
        text: 'Songs you listen to will show up here.',
      );
    }
    return SizedBox(
      height: _cardRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: HaraSpacing.md),
        itemBuilder: (context, i) => _SongCard(
          song: songs[i],
          onTap: () => playSongs(
            ref,
            songs,
            index: i,
            source: PlaySource.songs,
            label: 'Recently played',
          ),
        ),
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.onTap});

  final SongRow song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = song.artist ?? songSubtitle(song, showAlbum: false);
    return Semantics(
      button: true,
      label: '${song.title}, $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: HomeScreen.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SongArtwork(
                songId: song.id,
                albumId: song.albumId,
                version: song.dateModified,
                size: HomeScreen.cardWidth - HaraShadow.offset,
                shadow: true,
                borderRadius: HaraRadius.lg,
                borderWidth: HaraBorder.regular,
              ),
              const SizedBox(height: HaraShadow.offset + HaraSpacing.sm),
              Text(
                song.title,
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MostPlayedList extends ConsumerWidget {
  const _MostPlayedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(mostPlayedProvider).value;
    if (top == null) return const SizedBox.shrink();
    if (top.isEmpty) {
      return const _RowHint(
        icon: HaraIcons.chartColumn,
        text: 'Your top songs appear once you have played a few.',
      );
    }
    final songs = [for (final p in top) p.song];
    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          LibrarySongTile(
            song: top[i].song,
            subtitle:
                '${top[i].plays == 1 ? '1 play' : '${top[i].plays} plays'}'
                ' · ${songSubtitle(top[i].song, showAlbum: false)}',
            onTap: () => playSongs(
              ref,
              songs,
              index: i,
              source: PlaySource.songs,
              label: 'Most played',
            ),
          ),
      ],
    );
  }
}

class _RecentlyAddedRow extends ConsumerWidget {
  const _RecentlyAddedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(recentlyAddedAlbumsProvider).value;
    if (albums == null || albums.isEmpty) {
      return const SizedBox(height: _cardRowHeight);
    }
    return SizedBox(
      height: _cardRowHeight + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
        itemCount: albums.length,
        separatorBuilder: (_, _) => const SizedBox(width: HaraSpacing.md),
        itemBuilder: (context, i) {
          final album = albums[i];
          final id = album.albumId;
          return SizedBox(
            width: HomeScreen.cardWidth,
            child: AlbumCard(
              album: album,
              onTap: id == null
                  ? () => context.push(
                      AppRoutes.artist(album.artist, tab: AppRoutes.home),
                    )
                  : () =>
                        context.push(AppRoutes.album(id, tab: AppRoutes.home)),
            ),
          );
        },
      ),
    );
  }
}
