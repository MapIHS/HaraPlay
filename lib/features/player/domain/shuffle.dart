import 'dart:math';

/// HaraPlay's own shuffle (docs/PLAN.md §3): the queue is physically
/// reordered, so the queue shows the real play order. A shuffled queue is
/// described by `order`, where `order[playPosition]` is the entry's index
/// in the original queue. Working with indexes (not songs) keeps a song
/// that is queued twice unambiguous.

/// A shuffled order of `0..length-1` that starts with [current].
List<int> shuffleOrder(int length, int current, Random random) {
  assert(current >= 0 && current < length, 'current out of range');
  final rest = [
    for (var i = 0; i < length; i++)
      if (i != current) i,
  ]..shuffle(random);
  return [current, ...rest];
}

/// Rebuilds the permutation from two song-ID lists: the play order and the
/// original order. Duplicates are matched first-come, first-served. Returns
/// null if the lists are not permutations of each other.
List<int>? orderFromIds(List<int> playIds, List<int> originalIds) {
  if (playIds.length != originalIds.length) return null;
  final free = <int, List<int>>{};
  for (final (index, id) in originalIds.indexed) {
    (free[id] ??= []).add(index);
  }
  final order = <int>[];
  for (final id in playIds) {
    final candidates = free[id];
    if (candidates == null || candidates.isEmpty) return null;
    order.add(candidates.removeAt(0));
  }
  return order;
}
