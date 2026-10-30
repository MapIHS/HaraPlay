// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_dao.dart';

// ignore_for_file: type=lint
mixin _$LibraryDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
  $SongTagFallbacksTable get songTagFallbacks =>
      attachedDatabase.songTagFallbacks;
  LibraryDaoManager get managers => LibraryDaoManager(this);
}

class LibraryDaoManager {
  final _$LibraryDaoMixin _db;
  LibraryDaoManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$SongTagFallbacksTableTableManager get songTagFallbacks =>
      $$SongTagFallbacksTableTableManager(
        _db.attachedDatabase,
        _db.songTagFallbacks,
      );
}
