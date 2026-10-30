import 'package:drift/drift.dart';

import '../app_database.dart';

part 'play_events_dao.g.dart';

/// Writes and reads the append-only listening history.
@DriftAccessor(tables: [PlayEvents])
class PlayEventsDao extends DatabaseAccessor<AppDatabase>
    with _$PlayEventsDaoMixin {
  PlayEventsDao(super.attachedDatabase);

  Future<int> insertEvent(PlayEventsCompanion event) =>
      into(playEvents).insert(event);

  Future<void> updateProgress(
    int id, {
    required int listenedMs,
    required bool completed,
  }) => (update(playEvents)..where((e) => e.id.equals(id))).write(
    PlayEventsCompanion(
      listenedMs: Value(listenedMs),
      completed: Value(completed),
    ),
  );

  /// Newest first (debug screen; Home and Stats get their own queries).
  Stream<List<PlayEventRow>> watchRecent({int limit = 20}) =>
      (select(playEvents)
            ..orderBy([
              (e) => OrderingTerm(
                expression: e.startedAt,
                mode: OrderingMode.desc,
              ),
              (e) => OrderingTerm(expression: e.id, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .watch();
}
