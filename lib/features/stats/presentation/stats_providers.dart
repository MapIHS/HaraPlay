import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/stats_dao.dart';
import '../domain/stats_range.dart';

final statsDaoProvider = Provider<StatsDao>(
  (ref) => ref.watch(appDatabaseProvider).statsDao,
);

class StatsRangeController extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.month;

  // ignore: use_setters_to_change_properties
  void select(StatsRange range) => state = range;
}

final statsRangeProvider = NotifierProvider<StatsRangeController, StatsRange>(
  StatsRangeController.new,
);

/// Everything the Stats tab shows for one range.
class StatsData {
  const StatsData({
    required this.summary,
    required this.hours,
    required this.weekdays,
    required this.heatmapStart,
    required this.days,
    required this.topSongs,
    required this.songRows,
    required this.topArtists,
    required this.topAlbums,
  });

  final StatsSummary summary;
  final List<Duration> hours;
  final List<Duration> weekdays;

  /// Monday (local date, as UTC midnight) of the heatmap's first week.
  final DateTime heatmapStart;

  /// Listening per local date (UTC midnight keys), since [heatmapStart].
  final Map<DateTime, Duration> days;
  final List<TopEntry> topSongs;

  /// Library rows of the top songs that still exist (for artwork).
  final Map<int, SongRow> songRows;
  final List<TopEntry> topArtists;
  final List<TopEntry> topAlbums;

  bool get isEmpty => summary.listened == Duration.zero;
}

/// The heatmap always covers this many weeks, ending with this week.
const heatmapWeeks = 20;

final statsProvider = FutureProvider.autoDispose.family<StatsData, StatsRange>((
  ref,
  range,
) async {
  final dao = ref.watch(statsDaoProvider);
  final db = ref.watch(appDatabaseProvider);
  final now = clock.now();
  final offset = now.timeZoneOffset;
  final since = range.since(now);

  final today = DateTime.utc(now.year, now.month, now.day);
  final heatmapStart = today.subtract(
    Duration(days: today.weekday - 1 + (heatmapWeeks - 1) * 7),
  );
  final heatmapSince = DateTime(
    heatmapStart.year,
    heatmapStart.month,
    heatmapStart.day,
  );

  final topSongs = await dao.topSongs(since: since);
  final ids = [for (final s in topSongs) ?s.songId];
  return StatsData(
    summary: await dao.summary(since: since),
    hours: await dao.byHour(since: since, utcOffset: offset),
    weekdays: await dao.byWeekday(since: since, utcOffset: offset),
    heatmapStart: heatmapStart,
    days: await dao.byDay(since: heatmapSince, utcOffset: offset),
    topSongs: topSongs,
    songRows: await db.queueStateDao.songsByIds(ids),
    topArtists: await dao.topArtists(since: since),
    topAlbums: await dao.topAlbums(since: since),
  );
});

/// History pages loaded so far.
class HistoryState {
  const HistoryState({
    this.events = const [],
    this.hasMore = true,
    this.loading = false,
  });

  final List<PlayEventRow> events;
  final bool hasMore;
  final bool loading;
}

class HistoryController extends Notifier<HistoryState> {
  static const pageSize = 50;

  @override
  HistoryState build() {
    Future.microtask(loadMore);
    return const HistoryState(loading: true);
  }

  bool _busy = false;

  /// Appends the next page; does nothing while a page is loading or when
  /// everything is loaded.
  Future<void> loadMore() async {
    final current = state;
    if (_busy || !current.hasMore) return;
    _busy = true;
    state = HistoryState(events: current.events, loading: true);
    final page = await ref
        .read(statsDaoProvider)
        .history(
          after: current.events.isEmpty ? null : current.events.last,
          limit: pageSize,
        );
    _busy = false;
    if (!ref.mounted) return;
    state = HistoryState(
      events: [...current.events, ...page],
      hasMore: page.length == pageSize,
    );
  }
}

final historyProvider =
    NotifierProvider.autoDispose<HistoryController, HistoryState>(
      HistoryController.new,
    );
