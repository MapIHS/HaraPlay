import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/player/data/play_event_recorder.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Duration now; // monotonic test clock
  late PlayEventRecorder recorder;

  QueueSong song(int id, {int seconds = 200}) => QueueSong(
    id: id,
    title: 'Song $id',
    artist: 'Kai Tone',
    album: 'Double Feature',
    path: '/m/$id.mp3',
    duration: Duration(seconds: seconds),
    version: 1,
  );

  void advance(int seconds) => now += Duration(seconds: seconds);

  Future<List<PlayEventRow>> events() async {
    await recorder.flush();
    return (db.select(
      db.playEvents,
    )..orderBy([(e) => OrderingTerm(expression: e.id)])).get();
  }

  setUp(() async {
    db = createTestDatabase();
    await db.libraryDao.applyScan([
      for (var i = 1; i <= 3; i++) mediaSong(i, path: '/m/$i.mp3'),
    ]);
    now = Duration.zero;
    recorder = PlayEventRecorder(
      db.playEventsDao,
      monotonic: () => now,
      wallClock: () => DateTime.utc(2026, 10, 30, 12).add(now),
    );
  });
  tearDown(() => db.close());

  test('counts only time spent playing; seeking adds nothing', () async {
    recorder
      ..trackChanged(song(1), source: PlaySource.album)
      ..activeChanged(true);
    advance(20);
    recorder.positionChanged(const Duration(seconds: 20));
    // Seek far ahead: no listened time is added by the jump.
    recorder.positionChanged(const Duration(seconds: 150));
    advance(5);
    recorder
      ..positionChanged(const Duration(seconds: 155))
      ..activeChanged(false); // paused
    advance(60); // paused time does not count
    recorder.trackChanged(song(2), source: PlaySource.album); // skip

    final rows = await events();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.songId, 1);
    expect(row.listenedMs, 25000);
    expect(row.completed, isFalse);
    expect(row.source, PlaySource.album);
    expect(row.title, 'Song 1');
    expect(row.artist, 'Kai Tone');
    expect(row.durationMs, 200000);
    expect(
      row.startedAt,
      DateTime.utc(2026, 10, 30, 12).millisecondsSinceEpoch,
    );
  });

  test('playing into the next track writes one row per track', () async {
    recorder
      ..trackChanged(song(1, seconds: 30), source: PlaySource.songs)
      ..activeChanged(true);
    advance(30);
    recorder
      ..positionChanged(const Duration(seconds: 30))
      // Gapless transition: still playing, new track.
      ..trackChanged(song(2), source: PlaySource.songs);
    advance(12);
    recorder.positionChanged(const Duration(seconds: 12));

    final rows = await events();
    expect(rows.map((r) => (r.songId, r.listenedMs, r.completed)), [
      (1, 30000, true),
      (2, 12000, false),
    ]);
  });

  test('restarting the same track starts a new listen', () async {
    recorder
      ..trackChanged(song(1, seconds: 45), source: PlaySource.songs)
      ..activeChanged(true);
    advance(35);
    recorder
      ..positionChanged(const Duration(seconds: 35))
      ..trackRestarted(); // "previous" after 3 s
    advance(45);
    recorder.positionChanged(const Duration(seconds: 45));

    final rows = await events();
    expect(rows.map((r) => (r.songId, r.listenedMs, r.completed)), [
      (1, 35000, false),
      (1, 45000, true),
    ]);
  });

  test('leaving a track within two seconds of its end completes it', () async {
    recorder
      ..trackChanged(song(1, seconds: 100), source: PlaySource.songs)
      ..activeChanged(true);
    advance(10);
    recorder
      ..positionChanged(const Duration(seconds: 98, milliseconds: 500))
      ..trackChanged(song(2), source: PlaySource.songs);
    expect((await events()).first.completed, isTrue);
  });

  test('the end of the queue marks the last track completed', () async {
    recorder
      ..trackChanged(song(1), source: PlaySource.folder)
      ..activeChanged(true);
    advance(40);
    recorder.trackEnded();
    final row = (await events()).single;
    expect(row.completed, isTrue);
    expect(row.listenedMs, 40000);
  });

  test('very short listens are not stored', () async {
    recorder
      ..trackChanged(song(1), source: PlaySource.songs)
      ..activeChanged(true);
    now += const Duration(milliseconds: 400);
    recorder.trackChanged(song(2), source: PlaySource.songs);
    advance(3);
    final rows = await events();
    expect(rows.map((r) => r.songId), [2]);
  });

  test('a song that never plays leaves no row', () async {
    recorder.trackChanged(song(1), source: PlaySource.songs);
    advance(30);
    recorder.trackChanged(song(2), source: PlaySource.songs);
    expect(await events(), isEmpty);
  });

  test('progress is saved while playing, so a crash loses little', () async {
    recorder
      ..trackChanged(song(1), source: PlaySource.songs)
      ..activeChanged(true);
    advance(25);
    recorder.positionChanged(const Duration(seconds: 25));
    // No flush: read what is already in the database.
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();
    final saved = await db.select(db.playEvents).getSingle();
    expect(saved.listenedMs, greaterThanOrEqualTo(10000));
  });

  test('pausing saves progress', () async {
    recorder
      ..trackChanged(song(1), source: PlaySource.songs)
      ..activeChanged(true);
    advance(7);
    recorder.activeChanged(false);
    await pumpEventQueue();
    expect((await db.select(db.playEvents).getSingle()).listenedMs, 7000);
  });

  test('a rejected write never throws into playback', () async {
    // Song 99 is not in the library: the foreign key rejects the insert.
    recorder
      ..trackChanged(song(99), source: PlaySource.songs)
      ..activeChanged(true);
    advance(5);
    recorder.trackChanged(song(1), source: PlaySource.songs);
    advance(5);
    final rows = await events();
    expect(rows.map((r) => r.songId), [1]);
  });
}
