import 'dart:math';

import 'queue_song.dart';
import 'shuffle.dart';

/// The queue in play order, plus (while shuffled) the order it would have
/// without shuffle. Every edit keeps both consistent, so turning shuffle
/// off after editing still restores a sensible order.
///
/// Positions are play-order indexes, as shown in the queue sheet.
class QueueModel {
  QueueModel(List<QueueSong> songs) : _original = [...songs];

  /// Restores a queue as saved: [original] plus an optional shuffle [order]
  /// (`order[playPosition]` = index in [original]).
  QueueModel.restored(List<QueueSong> original, List<int>? order)
    : _original = [...original],
      _order = order == null ? null : [...order];

  final List<QueueSong> _original;
  List<int>? _order;

  bool get shuffled => _order != null;
  int get length => _original.length;

  /// Play order.
  List<QueueSong> get songs => _order == null
      ? List.unmodifiable(_original)
      : List.unmodifiable([for (final i in _order!) _original[i]]);

  /// Order without shuffle.
  List<QueueSong> get original => List.unmodifiable(_original);

  /// Shuffles everything except [current], which moves to the front.
  /// Returns the new play position of the current song (always 0).
  int shuffle(int current, Random random) {
    if (shuffled) return current;
    _order = shuffleOrder(_original.length, current, random);
    return 0;
  }

  /// Back to the original order. Returns the current song's new position.
  int unshuffle(int current) {
    final order = _order;
    if (order == null) return current;
    _order = null;
    return order[current];
  }

  /// Inserts [items] at play position [at]. While shuffled they also enter
  /// the original order right after the entry that precedes them in play
  /// order, or at the end when appended.
  void insert(int at, List<QueueSong> items) {
    if (items.isEmpty) return;
    final order = _order;
    if (order == null) {
      _original.insertAll(at, items);
      return;
    }
    final originalAt = at >= order.length
        ? _original.length
        : at == 0
        ? 0
        : order[at - 1] + 1;
    _original.insertAll(originalAt, items);
    for (var i = 0; i < order.length; i++) {
      if (order[i] >= originalAt) order[i] += items.length;
    }
    order.insertAll(at, [
      for (var k = 0; k < items.length; k++) originalAt + k,
    ]);
  }

  void removeAt(int position) {
    final order = _order;
    if (order == null) {
      _original.removeAt(position);
      return;
    }
    final originalIndex = order.removeAt(position);
    _original.removeAt(originalIndex);
    for (var i = 0; i < order.length; i++) {
      if (order[i] > originalIndex) order[i] -= 1;
    }
  }

  /// Removes play positions [start] (inclusive) to [end] (exclusive).
  void removeRange(int start, int end) {
    for (var position = end - 1; position >= start; position--) {
      removeAt(position);
    }
  }

  /// Moves the entry at play position [from] so that it ends up at [to].
  /// While shuffled only the play order changes.
  void move(int from, int to) {
    final order = _order;
    if (order == null) {
      _original.insert(to, _original.removeAt(from));
    } else {
      order.insert(to, order.removeAt(from));
    }
  }

  /// For saving: the shuffle permutation, or null.
  List<int>? get order => _order == null ? null : List.unmodifiable(_order!);
}
