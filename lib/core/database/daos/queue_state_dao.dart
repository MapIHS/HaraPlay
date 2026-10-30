import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'queue_state_dao.g.dart';

/// The saved queue, restored (paused) on the next launch.
class SavedQueue {
  const SavedQueue({
    required this.songIds,
    required this.originalSongIds,
    required this.currentIndex,
    required this.position,
    required this.shuffle,
    required this.repeat,
    required this.source,
  });

  /// Play order.
  final List<int> songIds;

  /// Order before shuffling; null while shuffle is off.
  final List<int>? originalSongIds;
  final int currentIndex;
  final Duration position;
  final bool shuffle;
  final RepeatSetting repeat;
  final PlaySource source;
}

@DriftAccessor(tables: [QueueState, Songs])
class QueueStateDao extends DatabaseAccessor<AppDatabase>
    with _$QueueStateDaoMixin {
  QueueStateDao(super.attachedDatabase);

  Future<void> save(SavedQueue queue, {required DateTime at}) =>
      into(queueState).insertOnConflictUpdate(
        QueueStateCompanion.insert(
          id: const Value(1),
          songIds: jsonEncode(queue.songIds),
          originalSongIds: Value(
            queue.originalSongIds == null
                ? null
                : jsonEncode(queue.originalSongIds),
          ),
          currentIndex: queue.currentIndex,
          positionMs: queue.position.inMilliseconds,
          shuffle: queue.shuffle,
          repeatMode: queue.repeat,
          source: queue.source,
          updatedAt: at.millisecondsSinceEpoch,
        ),
      );

  /// Only the position changed (frequent while playing).
  Future<void> savePosition(
    int currentIndex,
    Duration position, {
    required DateTime at,
  }) => (update(queueState)..where((q) => q.id.equals(1))).write(
    QueueStateCompanion(
      currentIndex: Value(currentIndex),
      positionMs: Value(position.inMilliseconds),
      updatedAt: Value(at.millisecondsSinceEpoch),
    ),
  );

  Future<SavedQueue?> load() async {
    final row = await (select(
      queueState,
    )..where((q) => q.id.equals(1))).getSingleOrNull();
    if (row == null) return null;
    try {
      return SavedQueue(
        songIds: _ids(row.songIds),
        originalSongIds: row.originalSongIds == null
            ? null
            : _ids(row.originalSongIds!),
        currentIndex: row.currentIndex,
        position: Duration(milliseconds: row.positionMs),
        shuffle: row.shuffle,
        repeat: row.repeatMode,
        source: row.source,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() => delete(queueState).go();

  /// Songs by ID; IDs that no longer exist are simply missing.
  Future<Map<int, SongRow>> songsByIds(Iterable<int> ids) async {
    final unique = ids.toSet().toList();
    final result = <int, SongRow>{};
    // SQLite limits the number of variables per statement.
    for (var start = 0; start < unique.length; start += 500) {
      final chunk = unique.skip(start).take(500).toList();
      for (final row in await (select(
        songs,
      )..where((s) => s.id.isIn(chunk))).get()) {
        result[row.id] = row;
      }
    }
    return result;
  }

  static List<int> _ids(String json) => [
    for (final id in jsonDecode(json) as List<Object?>)
      if (id is int) id else throw const FormatException('bad song id'),
  ];
}
