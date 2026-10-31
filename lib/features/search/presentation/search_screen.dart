import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/widgets/album_card.dart';
import '../../library/presentation/widgets/library_row.dart';
import '../../library/presentation/widgets/library_song_tile.dart';
import '../../player/presentation/play_actions.dart';
import 'search_providers.dart';

/// Search tab: a field, recent searches while it is empty, and results
/// grouped into Songs, Albums and Artists.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  /// Pause after the last keystroke before searching.
  static const debounce = Duration(milliseconds: 150);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  /// Shown while the next query loads, so results don't flash away.
  SearchResults? _lastResults;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(SearchScreen.debounce, () {
      if (mounted) setState(() => _query = text.trim());
    });
    // Rebuild for the clear button.
    setState(() {});
  }

  void _setText(String text) {
    _debounce?.cancel();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _query = text.trim());
  }

  /// Remembers the query once the user acts on it.
  void _remember() => ref.read(recentSearchesProvider.notifier).add(_query);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              0,
              HaraSpacing.gutter,
              HaraSpacing.sm,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Songs, albums, artists',
                prefixIcon: const Icon(
                  HaraIcons.search,
                  size: HaraSizes.iconSmall,
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : HaraIconButton(
                        icon: HaraIcons.x,
                        tooltip: 'Clear search',
                        iconSize: HaraSizes.iconSmall,
                        onPressed: () {
                          _setText('');
                          _focus.requestFocus();
                        },
                      ),
              ),
              onChanged: _onChanged,
              onSubmitted: (text) {
                _setText(text);
                _remember();
              },
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? _RecentSearches(onPick: _setText)
                : _results(),
          ),
        ],
      ),
    );
  }

  Widget _results() {
    final value = ref.watch(searchResultsProvider(_query));
    final results = value.value ?? _lastResults;
    if (value.hasValue) _lastResults = value.value;
    if (value.hasError) {
      return const EmptyState(
        icon: HaraIcons.circleAlert,
        title: "Couldn't search",
        message: 'Something went wrong reading the music database.',
      );
    }
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty) {
      return EmptyState(
        icon: HaraIcons.search,
        title: 'No matches',
        message: 'Nothing on this phone matches "$_query".',
      );
    }
    return _ResultList(
      key: ValueKey(_query),
      query: _query,
      results: results,
      onAct: _remember,
    );
  }
}

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final controller = ref.read(recentSearchesProvider.notifier);
    if (recent.isEmpty) {
      return const EmptyState(
        icon: HaraIcons.search,
        title: 'Search your music',
        message: 'Find songs, albums and artists on this phone.',
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final colors = HaraColors.of(context);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _GroupHeader(
          title: 'Recent searches',
          actionLabel: 'Clear',
          onAction: controller.clear,
        ),
        for (final query in recent)
          Semantics(
            button: true,
            label: 'Search for $query',
            child: InkWell(
              onTap: () => onPick(query),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: HaraSpacing.gutter,
                  right: HaraSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      HaraIcons.history,
                      size: HaraSizes.iconSmall,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(width: HaraSpacing.lg),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          query,
                          style: textTheme.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    HaraIconButton(
                      icon: HaraIcons.x,
                      tooltip: 'Remove "$query" from recent searches',
                      iconSize: HaraSizes.iconSmall,
                      onPressed: () => controller.remove(query),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "SONGS · 12" with an optional "See all" / "Show less" toggle.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaraSpacing.gutter,
        HaraSpacing.md,
        HaraSpacing.xs,
        HaraSpacing.xs,
      ),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  [
                    title.toUpperCase(),
                    if (count != null) '$count',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelLarge!
                      .copyWith(color: colors.mutedForeground),
                ),
              ),
            ),
            if (actionLabel != null)
              HaraButton(
                label: actionLabel!,
                variant: HaraButtonVariant.ghost,
                size: HaraButtonSize.small,
                onPressed: onAction,
              ),
          ],
        ),
      ),
    );
  }
}

enum _Group { songs, albums, artists }

class _ResultList extends ConsumerStatefulWidget {
  const _ResultList({
    super.key,
    required this.query,
    required this.results,
    required this.onAct,
  });

  final String query;
  final SearchResults results;
  final VoidCallback onAct;

  @override
  ConsumerState<_ResultList> createState() => _ResultListState();
}

class _ResultListState extends ConsumerState<_ResultList> {
  static const _collapsed = {
    _Group.songs: 5,
    _Group.albums: 3,
    _Group.artists: 3,
  };

  final _expanded = <_Group>{};

  /// The first rows of [items], or all of them when [group] is expanded.
  List<T> _visible<T>(_Group group, List<T> items) => _expanded.contains(group)
      ? items
      : items.take(_collapsed[group]!).toList();

  _GroupHeader _header(_Group group, String title, int count) => _GroupHeader(
    title: title,
    count: count,
    actionLabel: count <= _collapsed[group]!
        ? null
        : _expanded.contains(group)
        ? 'Show less'
        : 'See all',
    onAction: () => setState(() {
      if (!_expanded.remove(group)) _expanded.add(group);
    }),
  );

  void _open(String path) {
    widget.onAct();
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.results;
    final songs = _visible(_Group.songs, r.songs);
    final albums = _visible(_Group.albums, r.albums);
    final artists = _visible(_Group.artists, r.artists);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
      children: [
        if (r.songs.isNotEmpty) ...[
          _header(_Group.songs, 'Songs', r.songs.length),
          for (var i = 0; i < songs.length; i++)
            LibrarySongTile(
              song: songs[i],
              onTap: () {
                widget.onAct();
                playSongs(
                  ref,
                  r.songs,
                  index: i,
                  source: PlaySource.search,
                  label: widget.query,
                );
              },
            ),
        ],
        if (r.albums.isNotEmpty) ...[
          _header(_Group.albums, 'Albums', r.albums.length),
          for (final album in albums)
            LibraryRow(
              leading: SongArtwork(
                songId: album.coverSongId,
                albumId: album.albumId,
                version: album.coverVersion,
                size: HaraSizes.songTileArtwork,
              ),
              title: albumTitle(album),
              subtitle: albumArtist(album),
              onTap: () => _openAlbum(album),
            ),
        ],
        if (r.artists.isNotEmpty) ...[
          _header(_Group.artists, 'Artists', r.artists.length),
          for (final artist in artists)
            LibraryRow(
              leading: SongArtwork(
                songId: artist.coverSongId,
                albumId: artist.coverAlbumId,
                version: artist.coverVersion,
                size: HaraSizes.songTileArtwork,
              ),
              title: artist.name ?? unknownArtist,
              subtitle: artist.songCount == 1
                  ? '1 song'
                  : '${artist.songCount} songs',
              onTap: () =>
                  _open(AppRoutes.artist(artist.name, tab: AppRoutes.search)),
            ),
        ],
      ],
    );
  }

  void _openAlbum(AlbumSummary album) {
    final id = album.albumId;
    _open(
      id == null
          ? AppRoutes.artist(album.artist, tab: AppRoutes.search)
          : AppRoutes.album(id, tab: AppRoutes.search),
    );
  }
}
