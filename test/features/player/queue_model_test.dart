import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/player/domain/queue_model.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';

void main() {
  QueueSong s(int id) => QueueSong(
    id: id,
    title: 'Song $id',
    path: '/m/$id.mp3',
    duration: const Duration(minutes: 3),
    version: 1,
  );
  List<int> ids(List<QueueSong> songs) => [for (final x in songs) x.id];

  group('unshuffled', () {
    test('insert, remove, move work on the play order directly', () {
      final q = QueueModel([s(1), s(2), s(3)])
        ..insert(1, [s(9)]) // play next after song 1
        ..insert(4, [s(8)]); // add to the end
      expect(ids(q.songs), [1, 9, 2, 3, 8]);

      q.removeAt(2);
      expect(ids(q.songs), [1, 9, 3, 8]);

      q.move(3, 1);
      expect(ids(q.songs), [1, 8, 9, 3]);
      expect(q.order, isNull);
    });

    test('removeRange clears upcoming songs', () {
      final q = QueueModel([s(1), s(2), s(3), s(4)])..removeRange(2, 4);
      expect(ids(q.songs), [1, 2]);
    });
  });

  group('shuffled', () {
    late QueueModel q;
    setUp(() {
      q = QueueModel([s(1), s(2), s(3), s(4), s(5)]);
      expect(q.shuffle(2, Random(3)), 0); // song 3 is playing
      expect(q.songs.first.id, 3);
    });

    test('play next goes after the current song in both orders', () {
      q.insert(1, [s(9)]);
      expect(q.songs[1].id, 9);
      // In the original order it follows song 3 too.
      expect(ids(q.original), [1, 2, 3, 9, 4, 5]);

      // Turning shuffle off resumes at song 3, with 9 right after it.
      final back = q.unshuffle(0);
      expect(ids(q.songs), [1, 2, 3, 9, 4, 5]);
      expect(back, 2);
    });

    test('add to queue goes to the end of both orders', () {
      q.insert(q.length, [s(8), s(7)]);
      expect(ids(q.songs).sublist(5), [8, 7]);
      expect(ids(q.original), [1, 2, 3, 4, 5, 8, 7]);
    });

    test('removing keeps the orders consistent', () {
      final victim = q.songs[3].id;
      q.removeAt(3);
      expect(ids(q.songs), isNot(contains(victim)));
      expect(ids(q.original), isNot(contains(victim)));
      expect(ids(q.songs).toSet(), ids(q.original).toSet());
      q.unshuffle(0);
      expect(ids(q.songs), [
        for (final id in [1, 2, 3, 4, 5])
          if (id != victim) id,
      ]);
    });

    test('moving changes the play order but not the original', () {
      final before = ids(q.songs);
      q.move(4, 1);
      expect(ids(q.songs), [
        before[0],
        before[4],
        before[1],
        before[2],
        before[3],
      ]);
      expect(ids(q.original), [1, 2, 3, 4, 5]);
    });

    test('duplicates stay distinct entries', () {
      q.insert(1, [s(3)]); // the playing song queued again
      expect(ids(q.songs).where((id) => id == 3), hasLength(2));
      q.removeAt(1);
      expect(ids(q.songs).where((id) => id == 3), hasLength(1));
      expect(ids(q.original), [1, 2, 3, 4, 5]);
    });
  });

  test('restored keeps a saved permutation', () {
    final q = QueueModel.restored([s(1), s(2), s(3)], [2, 0, 1]);
    expect(ids(q.songs), [3, 1, 2]);
    expect(q.shuffled, isTrue);
    expect(q.unshuffle(0), 2);
  });
}
