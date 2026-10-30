import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daos/browse_dao.dart';
import 'daos/library_dao.dart';
import 'daos/play_events_dao.dart';
import 'daos/queue_state_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Songs,
    Favorites,
    Playlists,
    PlaylistEntries,
    PlayEvents,
    QueueState,
    SongTechInfo,
    SongTagFallbacks,
  ],
  daos: [LibraryDao, BrowseDao, PlayEventsDao, QueueStateDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device database, opened in a background isolate.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'haraplay'));

  /// v1: M4 schema. v2: songs.name_from_filename.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(songs, songs.nameFromFilename);
    },
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
