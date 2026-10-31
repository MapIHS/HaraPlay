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

class GenreDetailScreen extends ConsumerWidget {
  const GenreDetailScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DetailScaffold(
      songs: ref.watch(genreSongsProvider(name)),
      header: (songs) => DetailHeader(
        visual: IconTile(
          icon: HaraIcons.tag,
          seed: stableSeed(name),
          size: DetailHeader.visualSize,
          shadow: true,
        ),
        kicker: 'Genre',
        title: name,
        chips: countChips(songs),
        onPlay: () =>
            playSongs(ref, songs, source: PlaySource.genre, label: name),
        onShuffle: () =>
            shuffleSongs(ref, songs, source: PlaySource.genre, label: name),
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
              source: PlaySource.genre,
              label: name,
            ),
          ),
          childCount: songs.length,
        ),
      ),
    );
  }
}
