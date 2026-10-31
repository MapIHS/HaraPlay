import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/widgets/library_song_tile.dart';
import '../domain/playlist_models.dart';
import 'playlist_providers.dart';

/// Picks library songs to append to [playlist], in the order they were
/// ticked.
Future<void> showAddSongsSheet(
  BuildContext context,
  WidgetRef ref,
  PlaylistSummary playlist,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await showHaraSheet<List<int>>(
    context: context,
    scrollable: false,
    builder: (_) => AddSongsSheet(playlistName: playlist.name),
  );
  if (picked == null || picked.isEmpty) return;
  await ref
      .read(playlistsDaoProvider)
      .addSongs(playlist.id, picked, at: DateTime.now());
  final count = picked.length == 1 ? '1 song' : '${picked.length} songs';
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Added $count to ${playlist.name}')));
}

class AddSongsSheet extends ConsumerStatefulWidget {
  const AddSongsSheet({super.key, required this.playlistName});

  final String playlistName;

  @override
  ConsumerState<AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends ConsumerState<AddSongsSheet> {
  final _picked = <int>[];
  String _query = '';

  List<SongRow> _filter(List<SongRow> songs) {
    final words = foldForSearch(_query)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return songs;
    return [
      for (final song in songs)
        if (words.every(song.searchText.contains)) song,
    ];
  }

  void _toggle(int id) => setState(() {
    if (!_picked.remove(id)) _picked.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final songs = _filter(ref.watch(songsProvider).value ?? const []);
    final count = _picked.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HaraSpacing.gutter,
            0,
            HaraSpacing.gutter,
            HaraSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Add songs', style: textTheme.titleLarge),
              ),
              Text(
                'to ${widget.playlistName}',
                style: textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: HaraSpacing.md),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Filter songs',
                  prefixIcon: Icon(HaraIcons.search, size: HaraSizes.iconSmall),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty ? 'No songs in your library.' : 'No match.',
                    style: textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: songs.length,
                  itemExtent: HaraSizes.rowHeightOf(context),
                  itemBuilder: (context, i) => _PickRow(
                    song: songs[i],
                    picked: _picked.contains(songs[i].id),
                    onTap: () => _toggle(songs[i].id),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              HaraSpacing.sm,
              HaraSpacing.gutter,
              HaraSpacing.md,
            ),
            child: HaraButton(
              label: count == 0
                  ? 'Add songs'
                  : count == 1
                  ? 'Add 1 song'
                  : 'Add $count songs',
              icon: HaraIcons.plus,
              expand: true,
              onPressed: count == 0
                  ? null
                  : () => Navigator.of(context).pop(List.of(_picked)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.song,
    required this.picked,
    required this.onTap,
  });

  final SongRow song;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final subtitle = songSubtitle(song);
    return Semantics(
      label: '${song.title}, $subtitle',
      checked: picked,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
          child: Row(
            children: [
              SongArtwork(
                songId: song.id,
                albumId: song.albumId,
                version: song.dateModified,
                size: HaraSizes.songTileArtwork,
              ),
              const SizedBox(width: HaraSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: textTheme.titleMedium,
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
              const SizedBox(width: HaraSpacing.sm),
              // A bordered square check box in the HaraPlay style.
              AnimatedContainer(
                duration: HaraMotion.fast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: picked ? colors.primary : colors.surface,
                  borderRadius: BorderRadius.circular(HaraRadius.sm),
                  border: Border.all(
                    color: colors.border,
                    width: HaraBorder.regular,
                  ),
                ),
                child: picked
                    ? Icon(HaraIcons.check, size: 16, color: colors.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
