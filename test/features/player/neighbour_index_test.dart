import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';

void main() {
  int? next(int? current, int length, {bool wrap = false}) =>
      neighbourIndex(current: current, length: length, step: 1, wrap: wrap);
  int? previous(int? current, int length, {bool wrap = false}) =>
      neighbourIndex(current: current, length: length, step: -1, wrap: wrap);

  test('moves within the queue whatever the repeat mode', () {
    expect(next(0, 3), 1);
    expect(previous(2, 3), 1);
  });

  test('stops at the ends without repeat all', () {
    expect(next(2, 3), isNull);
    expect(previous(0, 3), isNull);
  });

  test('wraps around with repeat all', () {
    expect(next(2, 3, wrap: true), 0);
    expect(previous(0, 3, wrap: true), 2);
    expect(next(0, 1, wrap: true), 0);
  });

  test('nothing to move to without a queue', () {
    expect(next(null, 3), isNull);
    expect(next(0, 0), isNull);
  });
}
