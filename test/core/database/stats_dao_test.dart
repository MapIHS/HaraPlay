import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/stats_dao.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatsDao stats;

  setUp(() async {
    db = createTestDatabase();
    stats = db.statsDao;
    await db.libraryDao.applyScan([mediaSong(1), mediaSong(2), mediaSong(3)]);
  });
  tearDown(() => db.close());

  /// A listen at UTC [at] lasting [seconds] of a 3-minute song.
  Future<void> listen(
    DateTime at, {
    int song = 1,
    int seconds = 120,
    String? artist = 'Kai Tone',
    String? album = 'Roads',
    String? title,
    bool keepSongId = true,
  }) => db.playEventsDao.insertEvent(
    PlayEventsCompanion.insert(
      songId: Value(keepSongId ? song : null),
      songPath: '/m/$song.mp3',
      title: title ?? 'Song $song',
      artist: Value(artist),
      album: Value(album),
      startedAt: at.millisecondsSinceEpoch,
      listenedMs: seconds * 1000,
      durationMs: 180000,
      completed: false,
      source: PlaySource.songs,
    ),
  );

  final epoch = DateTime.utc(2000);

  test('summary counts all listening, but only real plays', () async {
    await listen(DateTime.utc(2026, 10, 1, 10), seconds: 120);
    await listen(DateTime.utc(2026, 10, 1, 11), seconds: 5); // a skip
    await listen(DateTime.utc(2026, 10, 2, 11), song: 2, seconds: 60);
    await listen(DateTime.utc(2025, 1, 1), song: 3); // before the range

    final s = await stats.summary(since: DateTime.utc(2026));
    expect(s.listened, const Duration(seconds: 185));
    expect(s.plays, 2);
    expect(s.songs, 2);
    expect((await stats.summary(since: epoch)).plays, 3);
  });

  test('hours and weekdays use the local time zone', () async {
    // 23:30 UTC on Sunday 2026-11-01 is 06:30 Monday in UTC+7.
    await listen(DateTime.utc(2026, 11, 1, 23, 30), seconds: 600);
    const utc7 = Duration(hours: 7);

    final hours = await stats.byHour(since: epoch, utcOffset: utc7);
    expect(hours, hasLength(24));
    expect(hours[6], const Duration(minutes: 10));
    expect(hours.where((d) => d > Duration.zero), hasLength(1));

    final days = await stats.byWeekday(since: epoch, utcOffset: utc7);
    expect(days, hasLength(7));
    expect(days[0], const Duration(minutes: 10)); // Monday

    final utcDays = await stats.byWeekday(
      since: epoch,
      utcOffset: Duration.zero,
    );
    expect(utcDays[6], const Duration(minutes: 10)); // Sunday in UTC
  });

  test('per-day totals are keyed by the local date', () async {
    const utc7 = Duration(hours: 7);
    await listen(DateTime.utc(2026, 11, 1, 23, 30), seconds: 60);
    await listen(DateTime.utc(2026, 11, 2, 1), seconds: 60);
    await listen(DateTime.utc(2026, 11, 1, 10), seconds: 30);
    final days = await stats.byDay(since: epoch, utcOffset: utc7);
    expect(days, {
      DateTime.utc(2026, 11, 2): const Duration(minutes: 2),
      DateTime.utc(2026, 11, 1): const Duration(seconds: 30),
    });
  });

  test('top songs, artists and albums by counted plays', () async {
    for (var i = 0; i < 3; i++) {
      await listen(DateTime.utc(2026, 10, 1, i), song: 2, artist: 'Ana Sine');
    }
    await listen(DateTime.utc(2026, 10, 2), song: 1);
    await listen(DateTime.utc(2026, 10, 3), song: 1, seconds: 3); // skip
    await listen(
      DateTime.utc(2026, 10, 4),
      song: 3,
      artist: null,
      album: null,
      keepSongId: false, // deleted since
      title: 'Gone Song',
    );

    final songs = await stats.topSongs(since: epoch);
    expect(
      [for (final s in songs) (s.title, s.plays)],
      [('Song 2', 3), ('Gone Song', 1), ('Song 1', 1)],
    );
    expect(songs[0].songId, 2);
    expect(songs[1].songId, isNull);

    final artists = await stats.topArtists(since: epoch);
    expect(
      [for (final a in artists) (a.title, a.plays)],
      [
        ('Ana Sine', 3),
        ('', 1), // unknown artist
        ('Kai Tone', 1),
      ],
    );

    final albums = await stats.topAlbums(since: epoch);
    expect(albums.first.title, 'Roads');
    expect(albums.first.subtitle, 'Ana Sine');
  });

  test('a renamed song is listed under its latest title', () async {
    await listen(DateTime.utc(2026, 10, 1), title: 'Old name');
    await listen(DateTime.utc(2026, 10, 2), title: 'New name');
    final songs = await stats.topSongs(since: epoch);
    expect(songs.single.title, 'New name');
    expect(songs.single.plays, 2);
  });

  test('history pages are newest first, without gaps or repeats', () async {
    final same = DateTime.utc(2026, 10, 5, 12);
    for (var i = 0; i < 5; i++) {
      await listen(same, title: 'Same time $i');
    }
    for (var i = 0; i < 4; i++) {
      await listen(DateTime.utc(2026, 10, 1 + i), title: 'Day $i');
    }

    final seen = <String>[];
    PlayEventRow? last;
    while (true) {
      final page = await stats.history(after: last, limit: 3);
      if (page.isEmpty) break;
      seen.addAll(page.map((e) => e.title));
      last = page.last;
    }
    expect(seen, hasLength(9));
    expect(seen.toSet(), hasLength(9));
    expect(seen.take(5).every((t) => t.startsWith('Same time')), isTrue);
    expect(seen.skip(5), ['Day 3', 'Day 2', 'Day 1', 'Day 0']);
  });
}
