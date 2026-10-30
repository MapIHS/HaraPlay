import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/player/domain/shuffle.dart';

void main() {
  test('the current entry stays first and every entry appears once', () {
    for (var seed = 0; seed < 50; seed++) {
      final order = shuffleOrder(10, 6, Random(seed));
      expect(order.first, 6);
      expect(order.toSet(), {for (var i = 0; i < 10; i++) i});
      expect(order, hasLength(10));
    }
  });

  test(
    'turning shuffle off restores the original order at the current song',
    () {
      final original = ['a', 'b', 'c', 'd', 'e'];
      final order = shuffleOrder(original.length, 2, Random(1));
      final played = [for (final i in order) original[i]];
      expect(played.first, 'c');

      // Play on to the fourth position in the shuffled queue, then turn off.
      const position = 3;
      final backIndex = order[position];
      expect(original[backIndex], played[position]);
    },
  );

  test('shuffling actually changes the order (statistically)', () {
    final orders = {
      for (var seed = 0; seed < 20; seed++)
        shuffleOrder(8, 0, Random(seed)).join(','),
    };
    expect(orders.length, greaterThan(15));
  });

  test('a single song shuffles to itself', () {
    expect(shuffleOrder(1, 0, Random(0)), [0]);
  });

  test('orderFromIds rebuilds the permutation, duplicates included', () {
    expect(orderFromIds([30, 10, 20], [10, 20, 30]), [2, 0, 1]);
    // Song 7 is queued twice.
    expect(orderFromIds([7, 9, 7], [7, 7, 9]), [0, 2, 1]);
    expect(orderFromIds([1, 2], [1, 3]), isNull);
    expect(orderFromIds([1], [1, 2]), isNull);
  });
}
