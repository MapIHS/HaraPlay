import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../library/presentation/widgets/detail_header.dart';
import '../../library/presentation/widgets/detail_scaffold.dart';
import '../../library/presentation/widgets/library_song_tile.dart';
import '../../player/presentation/play_actions.dart';
import '../domain/playlist_models.dart';
import 'add_songs_sheet.dart';
import 'playlist_cover.dart';
import 'playlist_providers.dart';
import 'playlists_screen.dart';

/// One playlist: header with Play / Shuffle, then its songs. Drag the grip
/// to reorder, swipe left to remove (with Undo).
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  /// The order after a local edit, shown until the database confirms it,
  /// so a dropped or swiped row doesn't jump back for a frame.
  List<PlaylistEntry>? _pending;
  List<PlaylistEntry>? _lastLoaded;

  int get _id => widget.playlistId;

  List<PlaylistEntry> _visible(List<PlaylistEntry> loaded) {
    if (!identical(loaded, _lastLoaded)) {
      _lastLoaded = loaded;
      _pending = null;
    }
    return _pending ?? loaded;
  }

  /// [to] is the final index (already adjusted for the moved row).
  void _move(List<PlaylistEntry> entries, int from, int to) {
    if (from == to) return;
    final next = [...entries];
    next.insert(to, next.removeAt(from));
    setState(() => _pending = next);
    ref.read(playlistsDaoProvider).moveEntry(_id, from, to, at: DateTime.now());
  }

  Future<void> _remove(List<PlaylistEntry> entries, int index) async {
    final entry = entries[index];
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending = [...entries]..removeAt(index));
    final dao = ref.read(playlistsDaoProvider);
    final removed = await dao.removeEntry(entry.entryId, at: DateTime.now());
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${entry.song.title}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => dao.restoreEntry(removed, at: DateTime.now()),
          ),
        ),
      );
  }

  void _addSongs(PlaylistSummary playlist) =>
      showAddSongsSheet(context, ref, playlist);

  @override
  Widget build(BuildContext context) {
    final playlistValue = ref.watch(playlistProvider(_id));
    final entriesValue = ref.watch(playlistEntriesProvider(_id));
    final playlist = playlistValue.value;

    final Widget body;
    if (playlistValue is AsyncError || entriesValue is AsyncError) {
      body = const EmptyState(
        icon: HaraIcons.circleAlert,
        title: "Couldn't load this playlist",
        message: 'Something went wrong reading the music database.',
      );
    } else if (playlistValue.hasValue && playlist == null) {
      body = const EmptyState(
        icon: HaraIcons.listMusic,
        title: 'Playlist not found',
        message: 'This playlist was deleted.',
      );
    } else if (playlist == null || !entriesValue.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _content(playlist, _visible(entriesValue.requireValue));
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (playlist != null)
            HaraIconButton(
              icon: HaraIcons.ellipsisVertical,
              tooltip: 'Playlist options',
              onPressed: () => showPlaylistActions(
                context,
                ref,
                playlist,
                onAddSongs: () => _addSongs(playlist),
                onDeleted: () => Navigator.of(context).maybePop(),
              ),
            ),
          const SizedBox(width: HaraSpacing.xs),
        ],
      ),
      body: body,
    );
  }

  Widget _content(PlaylistSummary playlist, List<PlaylistEntry> entries) {
    final songs = [for (final e in entries) e.song];
    final colors = HaraColors.of(context);

    void play({int index = 0}) => playSongs(
      ref,
      songs,
      index: index,
      source: PlaySource.playlist,
      label: playlist.name,
    );

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DetailHeader(
              visual: PlaylistCover(
                playlist: playlist,
                size: DetailHeader.visualSize,
                shadow: true,
              ),
              kicker: 'Playlist',
              title: playlist.name,
              chips: songs.isEmpty ? const [] : countChips(songs),
              onPlay: songs.isEmpty ? null : play,
              onShuffle: songs.isEmpty
                  ? null
                  : () => shuffleSongs(
                      ref,
                      songs,
                      source: PlaySource.playlist,
                      label: playlist.name,
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HaraSpacing.gutter,
                0,
                HaraSpacing.gutter,
                HaraSpacing.sm,
              ),
              child: songs.isEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This playlist is empty. Add songs here, or from '
                          'any song’s ⋮ menu.',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: colors.mutedForeground),
                        ),
                        const SizedBox(height: HaraSpacing.md),
                        HaraButton(
                          label: 'Add songs',
                          icon: HaraIcons.listPlus,
                          onPressed: () => _addSongs(playlist),
                        ),
                      ],
                    )
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: HaraButton(
                        label: 'Add songs',
                        icon: HaraIcons.listPlus,
                        variant: HaraButtonVariant.secondary,
                        size: HaraButtonSize.small,
                        onPressed: () => _addSongs(playlist),
                      ),
                    ),
            ),
          ),
          SliverReorderableList(
            itemCount: entries.length,
            onReorderItem: (from, to) => _move(entries, from, to),
            proxyDecorator: (child, index, animation) => Material(
              color: colors.surface,
              shape: Border.symmetric(
                horizontal: BorderSide(
                  color: colors.border,
                  width: HaraBorder.thin,
                ),
              ),
              child: child,
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final key = ValueKey(entry.entryId);
              return Dismissible(
                key: key,
                direction: DismissDirection.endToStart,
                background: const _RemoveBackground(),
                onDismissed: (_) => _remove(entries, index),
                child: Material(
                  type: MaterialType.transparency,
                  child: LibrarySongTile(
                    song: entry.song,
                    onTap: () => play(index: index),
                    onRemoveFromPlaylist: () => _remove(entries, index),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: Semantics(
                        label: 'Reorder',
                        child: SizedBox(
                          width: 40,
                          height: HaraSizes.minTouchTarget,
                          child: Icon(
                            HaraIcons.gripVertical,
                            size: HaraSizes.iconSmall,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: HaraSpacing.xxxl)),
        ],
      ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return ColoredBox(
      color: colors.danger,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: HaraSpacing.xl),
          child: Icon(HaraIcons.trash2, color: colors.onDanger),
        ),
      ),
    );
  }
}
