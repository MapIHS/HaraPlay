import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/icons/hara_icons.dart';
import '../../../../core/theme/hara_tokens.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hara_chip.dart';

/// Layout shared by the detail screens: app bar, a header built from the
/// loaded songs, extra slivers, then the song list.
class DetailScaffold extends ConsumerWidget {
  const DetailScaffold({
    super.key,
    required this.songs,
    required this.header,
    required this.songList,
    this.extraSlivers = const [],
  });

  final AsyncValue<List<SongRow>> songs;
  final Widget Function(List<SongRow> songs) header;
  final Widget Function(List<SongRow> songs) songList;
  final List<Widget> extraSlivers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(),
      body: switch (songs) {
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: HaraIcons.music,
          title: 'Nothing here',
          message:
              'These songs are no longer on this phone, or they are hidden '
              'by the "Hide short audio" setting.',
        ),
        AsyncData(:final value) => Scrollbar(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: header(value)),
              ...extraSlivers,
              songList(value),
              const SliverToBoxAdapter(
                child: SizedBox(height: HaraSpacing.xxxl),
              ),
            ],
          ),
        ),
        AsyncError() => const EmptyState(
          icon: HaraIcons.circleAlert,
          title: "Couldn't load these songs",
          message: 'Something went wrong reading the music database.',
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Song-count and total-length chips. [noun] is singular ("Song", "Track").
List<HaraChip> countChips(List<SongRow> songs, {String noun = 'Song'}) {
  final total = songs.fold(0, (sum, s) => sum + s.durationMs);
  return [
    HaraChip(
      value: '${songs.length}',
      label: songs.length == 1 ? noun : '${noun}s',
    ),
    HaraChip(
      value: formatTotalDuration(Duration(milliseconds: total)),
      label: 'Length',
    ),
  ];
}
