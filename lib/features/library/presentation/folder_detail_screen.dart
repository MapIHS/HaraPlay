import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../player/presentation/play_actions.dart';
import 'library_providers.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_scaffold.dart';
import 'widgets/library_row.dart';
import 'widgets/library_song_tile.dart';

class FolderDetailScreen extends ConsumerWidget {
  const FolderDetailScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DetailScaffold(
      songs: ref.watch(folderSongsProvider(path)),
      header: (songs) => DetailHeader(
        visual: IconTile(
          icon: HaraIcons.folderOpen,
          seed: stableSeed(path),
          size: DetailHeader.visualSize,
          shadow: true,
        ),
        kicker: 'Folder',
        title: songs.first.folderName,
        subtitle: path,
        chips: countChips(songs),
        onPlay: () => playSongs(
          ref,
          songs,
          source: PlaySource.folder,
          label: songs.first.folderName,
        ),
        onShuffle: () => shuffleSongs(
          ref,
          songs,
          source: PlaySource.folder,
          label: songs.first.folderName,
        ),
      ),
      songList: (songs) => SliverFixedExtentList(
        itemExtent: HaraSizes.rowHeightOf(context),
        delegate: SliverChildBuilderDelegate(
          (context, i) => LibrarySongTile(
            song: songs[i],
            onTap: () => playSongs(
              ref,
              songs,
              index: i,
              source: PlaySource.folder,
              label: songs.first.folderName,
            ),
          ),
          childCount: songs.length,
        ),
      ),
    );
  }
}
