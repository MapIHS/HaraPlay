import 'package:drift/drift.dart';

import '../app_database.dart';

part 'home_dao.g.dart';

/// SQL for "this listen counts as a play": at least 30 s, or half the song
/// if that is shorter (docs/PLAN.md §5). Applied at query time, so the rule
/// can change without losing history.
const countsAsPlaySql =
    'e.listened_ms >= MIN(30000, e.duration_ms / 2) AND e.listened_ms > 0';

/// A song with how often it was played (Most played).
class PlayedSong {
  const PlayedSong({required this.song, required this.plays});

  final SongRow song;
  final int plays;
}

/// Queries behind the Home rows. Songs hidden by "Hide short audio" are
/// left out, like everywhere else in the library.
@DriftAccessor(tables: [Songs, PlayEvents])
class HomeDao extends DatabaseAccessor<AppDatabase> with _$HomeDaoMixin {
  HomeDao(super.attachedDatabase);

  /// Songs by their last counted play, newest first, each once.
  Stream<List<SongRow>> watchRecentlyPlayed({
    required int minDurationMs,
    int limit = 12,
  }) => customSelect(
    'SELECT s.* FROM songs s JOIN ('
    '  SELECT e.song_id, MAX(e.started_at) AS last_played '
    '  FROM play_events e WHERE e.song_id IS NOT NULL AND $countsAsPlaySql '
    '  GROUP BY e.song_id'
    ') p ON p.song_id = s.id '
    'WHERE s.duration_ms >= ? '
    'ORDER BY p.last_played DESC LIMIT ?',
    variables: [Variable.withInt(minDurationMs), Variable.withInt(limit)],
    readsFrom: {songs, playEvents},
  ).map((row) => songs.map(row.data)).watch();

  /// Songs by counted plays; ties go to the one played last.
  Stream<List<PlayedSong>> watchMostPlayed({
    required int minDurationMs,
    int limit = 5,
  }) =>
      customSelect(
            'SELECT s.*, p.plays FROM songs s JOIN ('
            '  SELECT e.song_id, COUNT(*) AS plays, MAX(e.started_at) AS last_played '
            '  FROM play_events e WHERE e.song_id IS NOT NULL AND $countsAsPlaySql '
            '  GROUP BY e.song_id'
            ') p ON p.song_id = s.id '
            'WHERE s.duration_ms >= ? '
            'ORDER BY p.plays DESC, p.last_played DESC LIMIT ?',
            variables: [
              Variable.withInt(minDurationMs),
              Variable.withInt(limit),
            ],
            readsFrom: {songs, playEvents},
          )
          .map(
            (row) => PlayedSong(
              song: songs.map(row.data),
              plays: row.read<int>('plays'),
            ),
          )
          .watch();
}
