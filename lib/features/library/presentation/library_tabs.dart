import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_button.dart';
import '../domain/library_models.dart';
import '../domain/library_sort.dart';
import 'library_providers.dart';
import 'rescan.dart';
import 'widgets/album_card.dart';
import 'widgets/library_row.dart';
import 'widgets/library_song_tile.dart';
import 'widgets/sort_sheet.dart';

export 'rescan.dart' show rescanWithFeedback;

const _songSortLabels = {
  SongSortField.title: 'Title',
  SongSortField.artist: 'Artist',
  SongSortField.album: 'Album',
  SongSortField.dateAdded: 'Date added',
  SongSortField.duration: 'Length',
  SongSortField.size: 'File size',
};

const _albumSortLabels = {
  AlbumSortField.title: 'Title',
  AlbumSortField.artist: 'Artist',
  AlbumSortField.year: 'Year',
  AlbumSortField.songCount: 'Number of songs',
};

const _artistSortLabels = {
  ArtistSortField.name: 'Name',
  ArtistSortField.songCount: 'Number of songs',
};

const _folderSortLabels = {
  FolderSortField.name: 'Name',
  FolderSortField.songCount: 'Number of songs',
};

const _genreSortLabels = {
  GenreSortField.name: 'Name',
  GenreSortField.songCount: 'Number of songs',
};

String _count(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';

class SongsTab extends ConsumerWidget {
  const SongsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(songSortProvider);
    return _TabBody(
      storageKey: 'songs',
      items: ref.watch(songsProvider),
      summary: (songs) {
        final total = songs.fold(0, (sum, s) => sum + s.durationMs);
        return '${_count(songs.length, 'song')} · '
            '${formatTotalDuration(Duration(milliseconds: total))}';
      },
      sortLabel: _songSortLabels[sort.field]!,
      onSort: () => _pickSort(
        context,
        sort,
        _songSortLabels,
        ref.read(songSortProvider.notifier).set,
      ),
      emptyTitle: 'No songs',
      emptyMessage: 'Songs on this phone will appear here.',
      sliver: (songs) => SliverFixedExtentList(
        itemExtent: HaraSizes.songTileHeight,
        delegate: SliverChildBuilderDelegate(
          (context, i) => LibrarySongTile(song: songs[i]),
          childCount: songs.length,
        ),
      ),
    );
  }
}

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(albumSortProvider);
    return _TabBody(
      storageKey: 'albums',
      items: ref.watch(albumsProvider),
      summary: (albums) => _count(albums.length, 'album'),
      sortLabel: _albumSortLabels[sort.field]!,
      onSort: () => _pickSort(
        context,
        sort,
        _albumSortLabels,
        ref.read(albumSortProvider.notifier).set,
      ),
      emptyTitle: 'No albums',
      emptyMessage: 'Albums appear here once you have music.',
      sliver: (albums) => SliverLayoutBuilder(
        builder: (context, constraints) {
          const spacing = HaraSpacing.lg;
          final width = constraints.crossAxisExtent - HaraSpacing.gutter * 2;
          final columns = width >= 560 ? 3 : 2;
          final cellWidth = (width - spacing * (columns - 1)) / columns;
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              HaraSpacing.xs,
              HaraSpacing.gutter,
              HaraSpacing.lg,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                // Square artwork (minus its shadow inset) plus two text lines.
                mainAxisExtent:
                    cellWidth +
                    HaraSpacing.sm +
                    AlbumCard.labelHeight -
                    HaraShadow.offset,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => AlbumCard(
                  album: albums[i],
                  onTap: () => _openAlbum(context, albums[i]),
                ),
                childCount: albums.length,
              ),
            ),
          );
        },
      ),
    );
  }
}

void _openAlbum(BuildContext context, AlbumSummary album) {
  final id = album.albumId;
  if (id != null) context.push(AppRoutes.album(id));
}

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(artistSortProvider);
    return _TabBody(
      storageKey: 'artists',
      items: ref.watch(artistsProvider),
      summary: (artists) => _count(artists.length, 'artist'),
      sortLabel: _artistSortLabels[sort.field]!,
      onSort: () => _pickSort(
        context,
        sort,
        _artistSortLabels,
        ref.read(artistSortProvider.notifier).set,
      ),
      emptyTitle: 'No artists',
      emptyMessage: 'Artists appear here once you have music.',
      sliver: (artists) => SliverFixedExtentList(
        itemExtent: LibraryRow.height,
        delegate: SliverChildBuilderDelegate((context, i) {
          final artist = artists[i];
          return LibraryRow(
            leading: SongArtwork(
              songId: artist.coverSongId,
              albumId: artist.coverAlbumId,
              version: artist.coverVersion,
              size: HaraSizes.songTileArtwork,
              borderRadius: HaraRadius.pill,
            ),
            title: artist.name ?? unknownArtist,
            subtitle:
                '${_count(artist.songCount, 'song')} · '
                '${_count(artist.albumCount, 'album')}',
            onTap: () => context.push(AppRoutes.artist(artist.name)),
          );
        }, childCount: artists.length),
      ),
    );
  }
}

class FoldersTab extends ConsumerWidget {
  const FoldersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(folderSortProvider);
    return _TabBody(
      storageKey: 'folders',
      items: ref.watch(foldersProvider),
      summary: (folders) => _count(folders.length, 'folder'),
      sortLabel: _folderSortLabels[sort.field]!,
      onSort: () => _pickSort(
        context,
        sort,
        _folderSortLabels,
        ref.read(folderSortProvider.notifier).set,
      ),
      emptyTitle: 'No folders',
      emptyMessage: 'Folders with music appear here.',
      sliver: (folders) => SliverFixedExtentList(
        itemExtent: LibraryRow.height,
        delegate: SliverChildBuilderDelegate((context, i) {
          final folder = folders[i];
          return LibraryRow(
            leading: IconTile(
              icon: HaraIcons.folder,
              seed: stableSeed(folder.path),
            ),
            title: folder.name,
            subtitle: '${_count(folder.songCount, 'song')} · ${folder.path}',
            onTap: () => context.push(AppRoutes.folder(folder.path)),
          );
        }, childCount: folders.length),
      ),
    );
  }
}

class GenresTab extends ConsumerWidget {
  const GenresTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(genreSortProvider);
    return _TabBody(
      storageKey: 'genres',
      items: ref.watch(genresProvider),
      summary: (genres) => _count(genres.length, 'genre'),
      sortLabel: _genreSortLabels[sort.field]!,
      onSort: () => _pickSort(
        context,
        sort,
        _genreSortLabels,
        ref.read(genreSortProvider.notifier).set,
      ),
      emptyTitle: 'No genres',
      emptyMessage:
          'None of your songs has a genre tag. They are all under Songs.',
      sliver: (genres) => SliverFixedExtentList(
        itemExtent: LibraryRow.height,
        delegate: SliverChildBuilderDelegate((context, i) {
          final genre = genres[i];
          return LibraryRow(
            leading: IconTile(
              icon: HaraIcons.tag,
              seed: stableSeed(genre.name),
            ),
            title: genre.name,
            subtitle: _count(genre.songCount, 'song'),
            onTap: () => context.push(AppRoutes.genre(genre.name)),
          );
        }, childCount: genres.length),
      ),
    );
  }
}

Future<void> _pickSort<F extends Enum>(
  BuildContext context,
  LibrarySort<F> current,
  Map<F, String> labels,
  Future<void> Function(LibrarySort<F>) apply,
) async {
  final picked = await showSortSheet(
    context: context,
    current: current,
    labels: labels,
  );
  if (picked != null) await apply(picked);
}

/// Shared tab layout: summary line with a sort button, pull to rescan, a
/// draggable scrollbar, and loading / empty / error states.
class _TabBody<T> extends ConsumerWidget {
  const _TabBody({
    required this.storageKey,
    required this.items,
    required this.summary,
    required this.sortLabel,
    required this.onSort,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.sliver,
  });

  final String storageKey;
  final AsyncValue<List<T>> items;
  final String Function(List<T>) summary;
  final String sortLabel;
  final VoidCallback onSort;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(List<T>) sliver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (items) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        icon: HaraIcons.music,
        title: emptyTitle,
        message: emptyMessage,
      ),
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => rescanWithFeedback(context, ref),
        child: Scrollbar(
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(HaraRadius.pill),
          child: CustomScrollView(
            key: PageStorageKey(storageKey),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _SummaryBar(
                  text: summary(value),
                  sortLabel: sortLabel,
                  onSort: onSort,
                ),
              ),
              sliver(value),
              // Space for the mini player (M6) and breathing room.
              const SliverToBoxAdapter(
                child: SizedBox(height: HaraSpacing.xxxl),
              ),
            ],
          ),
        ),
      ),
      AsyncError() => EmptyState(
        icon: HaraIcons.circleAlert,
        title: "Couldn't load your library",
        message: 'Something went wrong reading the music database.',
        actionLabel: 'Scan again',
        onAction: () => rescanWithFeedback(context, ref),
      ),
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.text,
    required this.sortLabel,
    required this.onSort,
  });

  final String text;
  final String sortLabel;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: HaraSpacing.gutter,
        right: HaraSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: HaraTextStyles.of(context).mono,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            hint: 'Change sort order',
            child: HaraButton(
              label: sortLabel,
              icon: HaraIcons.arrowUpDown,
              variant: HaraButtonVariant.ghost,
              size: HaraButtonSize.small,
              onPressed: onSort,
            ),
          ),
        ],
      ),
    );
  }
}
