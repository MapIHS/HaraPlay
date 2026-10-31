import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/artwork/song_artwork.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/home_dao.dart';
import '../../../core/database/daos/stats_dao.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_chip.dart';
import '../../../core/widgets/hara_pills.dart';
import '../../../core/widgets/section_header.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/widgets/library_row.dart';
import '../../player/domain/queue_song.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/stats_range.dart';
import 'stats_charts.dart';
import 'stats_providers.dart';

/// Listening stats and history, from the play history the app records.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const tabs = ['Stats', 'History'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Listening'),
          bottom: const HaraPillTabBar(titles: tabs),
        ),
        body: const TabBarView(children: [_StatsTab(), _HistoryTab()]),
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statsRangeProvider);
    final data = ref.watch(statsProvider(range));
    return ListView(
      padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
      children: [
        HaraPillChoice<StatsRange>(
          values: StatsRange.values,
          selected: range,
          label: (r) => r.label,
          onChanged: ref.read(statsRangeProvider.notifier).select,
        ),
        ...switch (data) {
          AsyncData(:final value) when value.isEmpty => [
            const SizedBox(
              height: 360,
              child: EmptyState(
                icon: HaraIcons.chartColumn,
                title: 'Nothing played yet',
                message:
                    'Listen for a while and your habits show up here. '
                    'Try a longer range above.',
              ),
            ),
          ],
          AsyncData(:final value) => _sections(context, ref, value),
          AsyncError() => [
            const SizedBox(
              height: 360,
              child: EmptyState(
                icon: HaraIcons.circleAlert,
                title: "Couldn't load your stats",
                message: 'Something went wrong reading the play history.',
              ),
            ),
          ],
          AsyncLoading() => [
            const Padding(
              padding: EdgeInsets.all(HaraSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    );
  }

  List<Widget> _sections(BuildContext context, WidgetRef ref, StatsData d) {
    final now = clock.now();
    Widget padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
      child: child,
    );
    return [
      padded(
        Wrap(
          spacing: HaraSpacing.sm,
          runSpacing: HaraSpacing.sm,
          children: [
            HaraChip(
              value: formatTotalDuration(d.summary.listened),
              label: 'Listened',
            ),
            HaraChip(
              value: '${d.summary.plays}',
              label: d.summary.plays == 1 ? 'Play' : 'Plays',
            ),
            HaraChip(
              value: '${d.summary.songs}',
              label: d.summary.songs == 1 ? 'Song' : 'Songs',
            ),
          ],
        ),
      ),
      const SizedBox(height: HaraSpacing.lg),
      const SectionHeader(title: 'Time of day'),
      padded(
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: ListeningClock(hours: d.hours),
          ),
        ),
      ),
      const SizedBox(height: HaraSpacing.lg),
      const SectionHeader(title: 'Day of week'),
      padded(WeekdayBars(days: d.weekdays)),
      const SizedBox(height: HaraSpacing.lg),
      const SectionHeader(title: 'Last $heatmapWeeks weeks'),
      padded(
        ListeningHeatmap(
          start: d.heatmapStart,
          weeks: heatmapWeeks,
          days: d.days,
          today: DateTime.utc(now.year, now.month, now.day),
        ),
      ),
      const SizedBox(height: HaraSpacing.lg),
      const SectionHeader(title: 'Top songs'),
      for (final (i, entry) in d.topSongs.indexed)
        _TopSongRow(rank: i + 1, entry: entry, row: d.songRows[entry.songId]),
      const SizedBox(height: HaraSpacing.lg),
      const SectionHeader(title: 'Top artists'),
      for (final (i, entry) in d.topArtists.indexed)
        _TopRow(
          rank: i + 1,
          title: entry.title.isEmpty ? unknownArtist : entry.title,
          plays: entry.plays,
        ),
      const SizedBox(height: HaraSpacing.lg),
      const SectionHeader(title: 'Top albums'),
      for (final (i, entry) in d.topAlbums.indexed)
        _TopRow(
          rank: i + 1,
          title: entry.title.isEmpty ? unknownAlbum : entry.title,
          subtitle: entry.subtitle ?? unknownArtist,
          plays: entry.plays,
        ),
    ];
  }
}

String _plays(int n) => n == 1 ? '1 play' : '$n plays';

/// A rank number in mono type, sized for two digits.
class _Rank extends StatelessWidget {
  const _Rank(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    child: Text(
      '$rank',
      textAlign: TextAlign.center,
      style: HaraTextStyles.of(context).monoStrong,
    ),
  );
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.rank,
    required this.title,
    required this.plays,
    this.subtitle,
  });

  final int rank;
  final String title;
  final String? subtitle;
  final int plays;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final line = [?subtitle, _plays(plays)].join(' · ');
    return Semantics(
      label: '$rank. $title, $line',
      excludeSemantics: true,
      child: SizedBox(
        height: HaraSizes.rowHeightOf(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
          child: Row(
            children: [
              _Rank(rank),
              const SizedBox(width: HaraSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      line,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A top song with its artwork; tapping plays it if it's still here.
class _TopSongRow extends ConsumerWidget {
  const _TopSongRow({required this.rank, required this.entry, this.row});

  final int rank;
  final TopEntry entry;
  final SongRow? row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = this.row;
    final subtitle = [
      entry.subtitle ?? unknownArtist,
      _plays(entry.plays),
    ].join(' · ');
    return LibraryRow(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Rank(rank),
          const SizedBox(width: HaraSpacing.sm),
          if (row != null)
            SongArtwork(
              songId: row.id,
              albumId: row.albumId,
              version: row.dateModified,
              size: HaraSizes.songTileArtwork,
            )
          else
            const IconTile(icon: HaraIcons.music, seed: 0),
        ],
      ),
      title: entry.title,
      subtitle: row == null ? '$subtitle · no longer on this phone' : subtitle,
      onTap: row == null
          ? null
          : () => ref
                .read(playerProvider)
                .playSongs(
                  [QueueSong.fromRow(row)],
                  source: PlaySource.songs,
                  sourceLabel: 'Top songs',
                ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final events = history.events;
    if (events.isEmpty) {
      return history.loading
          ? const Center(child: CircularProgressIndicator())
          : const EmptyState(
              icon: HaraIcons.history,
              title: 'No history yet',
              message: 'Every song you listen to is listed here.',
            );
    }

    // Day headings between rows from different local days.
    final now = clock.now();
    final items = <Object>[];
    DateTime? lastDay;
    for (final event in events) {
      final at = DateTime.fromMillisecondsSinceEpoch(event.startedAt);
      final day = DateTime(at.year, at.month, at.day);
      if (day != lastDay) {
        items.add(dayHeading(day, now));
        lastDay = day;
      }
      items.add(event);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
      itemCount: items.length + (history.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          // The end of what's loaded: fetch the next page (after this
          // frame; providers can't change while the list builds).
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => ref.read(historyProvider.notifier).loadMore(),
          );
          return const Padding(
            padding: EdgeInsets.all(HaraSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return switch (items[i]) {
          final String heading => _DayHeading(heading),
          final PlayEventRow event => _HistoryRow(event: event),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HaraSpacing.gutter,
          HaraSpacing.lg,
          HaraSpacing.gutter,
          HaraSpacing.xs,
        ),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge!
              .copyWith(color: HaraColors.of(context).mutedForeground),
        ),
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.event});

  final PlayEventRow event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final at = DateTime.fromMillisecondsSinceEpoch(event.startedAt);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final counted = countsAsPlay(
      listenedMs: event.listenedMs,
      durationMs: event.durationMs,
    );
    final listened = formatDuration(Duration(milliseconds: event.listenedMs));
    final detail = counted ? 'Played $listened' : 'Skipped after $listened';
    final artist = event.artist ?? unknownArtist;
    final songId = event.songId;

    Future<void> play() async {
      final row = await ref.read(songByIdProvider(songId!).future);
      if (row == null) return;
      await ref
          .read(playerProvider)
          .playSongs(
            [QueueSong.fromRow(row)],
            source: PlaySource.songs,
            sourceLabel: 'History',
          );
    }

    return Semantics(
      button: songId != null,
      label: '$time, ${event.title}, $artist, $detail',
      excludeSemantics: true,
      onTap: songId == null ? null : play,
      child: InkWell(
        onTap: songId == null ? null : play,
        child: Opacity(
          opacity: counted ? 1 : 0.55,
          child: SizedBox(
            height: HaraSizes.rowHeightOf(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HaraSpacing.gutter,
              ),
              child: Row(
                children: [
                  // Wide enough for "12:50 PM"; shrinks rather than wraps.
                  SizedBox(
                    width: 68,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        time,
                        style: HaraTextStyles.of(context).mono,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: HaraSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$artist · $detail',
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (songId == null)
                    Icon(
                      HaraIcons.x,
                      size: HaraSizes.iconSmall,
                      color: colors.mutedForeground,
                      semanticLabel: 'No longer on this phone',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
