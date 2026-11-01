import 'package:drift/drift.dart';

import '../app_database.dart';
import 'home_dao.dart';

part 'stats_dao.g.dart';

/// Totals for a time range.
class StatsSummary {
  const StatsSummary({
    required this.listened,
    required this.plays,
    required this.songs,
  });

  /// All listening, skips included.
  final Duration listened;

  /// Listens that count as a play.
  final int plays;

  /// Different songs played.
  final int songs;
}

/// A ranked song, artist or album: [plays] counted plays.
class TopEntry {
  const TopEntry({
    required this.title,
    required this.plays,
    this.subtitle,
    this.songId,
    this.songPath,
  });

  final String title;
  final String? subtitle;
  final int plays;

  /// Set for songs that are still in the library.
  final int? songId;
  final String? songPath;
}

/// Listening statistics, all derived from `play_events`.
///
/// Times are grouped in the phone's local time: [utcOffset] is added to the
/// stored UTC timestamps, so the result doesn't depend on SQLite's own
/// notion of the time zone.
@DriftAccessor(tables: [PlayEvents, Songs])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.attachedDatabase);

  static const _day = 86400000;
  static const _hour = 3600000;

  Future<StatsSummary> summary({required DateTime since}) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(e.listened_ms), 0) AS listened, '
      'COALESCE(SUM(CASE WHEN $countsAsPlaySql THEN 1 ELSE 0 END), 0) '
      'AS plays, '
      'COUNT(DISTINCT CASE WHEN $countsAsPlaySql THEN e.song_path END) '
      'AS songs '
      'FROM play_events e WHERE e.started_at >= ?',
      variables: [Variable.withInt(since.millisecondsSinceEpoch)],
      readsFrom: {playEvents},
    ).getSingle();
    return StatsSummary(
      listened: Duration(milliseconds: row.read<int>('listened')),
      plays: row.read<int>('plays'),
      songs: row.read<int>('songs'),
    );
  }

  /// Listening per hour of the day (24 entries, local time).
  Future<List<Duration>> byHour({
    required DateTime since,
    required Duration utcOffset,
  }) => _buckets(
    since: since,
    key: '((e.started_at + ?) / $_hour) % 24',
    offset: utcOffset,
    count: 24,
  );

  /// Listening per weekday, Monday first (7 entries, local time).
  /// 1970-01-01 was a Thursday, so day 0 is weekday 3.
  Future<List<Duration>> byWeekday({
    required DateTime since,
    required Duration utcOffset,
  }) => _buckets(
    since: since,
    key: '((e.started_at + ?) / $_day + 3) % 7',
    offset: utcOffset,
    count: 7,
  );

  Future<List<Duration>> _buckets({
    required DateTime since,
    required String key,
    required Duration offset,
    required int count,
  }) async {
    final rows = await customSelect(
      'SELECT $key AS k, SUM(e.listened_ms) AS ms FROM play_events e '
      'WHERE e.started_at >= ? GROUP BY k',
      variables: [
        Variable.withInt(offset.inMilliseconds),
        Variable.withInt(since.millisecondsSinceEpoch),
      ],
      readsFrom: {playEvents},
    ).get();
    final result = List.filled(count, Duration.zero);
    for (final row in rows) {
      final k = row.read<int>('k');
      if (k >= 0 && k < count) {
        result[k] = Duration(milliseconds: row.read<int>('ms'));
      }
    }
    return result;
  }

  /// Listening per local calendar day since [since], keyed by the day's
  /// local midnight.
  Future<Map<DateTime, Duration>> byDay({
    required DateTime since,
    required Duration utcOffset,
  }) async {
    final rows = await customSelect(
      'SELECT (e.started_at + ?) / $_day AS d, SUM(e.listened_ms) AS ms '
      'FROM play_events e WHERE e.started_at >= ? GROUP BY d',
      variables: [
        Variable.withInt(utcOffset.inMilliseconds),
        Variable.withInt(since.millisecondsSinceEpoch),
      ],
      readsFrom: {playEvents},
    ).get();
    return {
      for (final row in rows)
        DateTime.utc(1970).add(Duration(days: row.read<int>('d'))): Duration(
          milliseconds: row.read<int>('ms'),
        ),
    };
  }

  /// Most played songs. Grouped by file, with the title and artist from
  /// the time of the last play, so deleted songs still show up.
  Future<List<TopEntry>> topSongs({
    required DateTime since,
    int limit = 5,
  }) => _top(
    since: since,
    group: 'e.song_path',
    select:
        'e.song_path AS path, MAX(e.song_id) AS song_id, '
        '(SELECT x.title FROM play_events x WHERE x.song_path = e.song_path '
        ' ORDER BY x.started_at DESC LIMIT 1) AS title, '
        '(SELECT x.artist FROM play_events x WHERE x.song_path = '
        'e.song_path ORDER BY x.started_at DESC LIMIT 1) AS sub',
    limit: limit,
    song: true,
  );

  Future<List<TopEntry>> topArtists({required DateTime since, int limit = 5}) =>
      _top(
        since: since,
        group: 'e.artist',
        select: 'e.artist AS title, NULL AS sub',
        limit: limit,
      );

  Future<List<TopEntry>> topAlbums({required DateTime since, int limit = 5}) =>
      _top(
        since: since,
        group: 'e.album, e.artist',
        select: 'e.album AS title, e.artist AS sub',
        limit: limit,
      );

  Future<List<TopEntry>> _top({
    required DateTime since,
    required String group,
    required String select,
    required int limit,
    bool song = false,
  }) async {
    final rows = await customSelect(
      'SELECT $select, COUNT(*) AS plays, MAX(e.started_at) AS last '
      'FROM play_events e WHERE e.started_at >= ? AND $countsAsPlaySql '
      'GROUP BY $group ORDER BY plays DESC, last DESC LIMIT ?',
      variables: [
        Variable.withInt(since.millisecondsSinceEpoch),
        Variable.withInt(limit),
      ],
      readsFrom: {playEvents},
    ).get();
    return [
      for (final row in rows)
        TopEntry(
          title: row.readNullable<String>('title') ?? '',
          subtitle: row.readNullable<String>('sub'),
          plays: row.read<int>('plays'),
          songId: song ? row.readNullable<int>('song_id') : null,
          songPath: song ? row.readNullable<String>('path') : null,
        ),
    ];
  }

  /// One page of history, newest first. [after] is the last row of the
  /// previous page (null for the first page); ties on the start time are
  /// broken by ID, so no listen is skipped or repeated across pages.
  Future<List<PlayEventRow>> history({PlayEventRow? after, int limit = 50}) =>
      (select(playEvents)
            ..where(
              (e) => after == null
                  ? const Constant(true)
                  : e.startedAt.isSmallerThanValue(after.startedAt) |
                        (e.startedAt.equals(after.startedAt) &
                            e.id.isSmallerThanValue(after.id)),
            )
            ..orderBy([
              (e) => OrderingTerm.desc(e.startedAt),
              (e) => OrderingTerm.desc(e.id),
            ])
            ..limit(limit))
          .get();
}
