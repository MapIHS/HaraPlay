import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import 'library_providers.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_scaffold.dart';
import 'widgets/library_row.dart';
import 'widgets/library_song_tile.dart';
import 'widgets/playback_soon.dart';

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
        onPlay: () => showPlaybackComingSoon(context),
        onShuffle: () => showPlaybackComingSoon(context),
      ),
      songList: (songs) => SliverFixedExtentList(
        itemExtent: HaraSizes.songTileHeight,
        delegate: SliverChildBuilderDelegate(
          (context, i) => LibrarySongTile(song: songs[i]),
          childCount: songs.length,
        ),
      ),
    );
  }
}
