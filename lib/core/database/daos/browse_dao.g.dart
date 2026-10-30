// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browse_dao.dart';

// ignore_for_file: type=lint
mixin _$BrowseDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
  BrowseDaoManager get managers => BrowseDaoManager(this);
}

class BrowseDaoManager {
  final _$BrowseDaoMixin _db;
  BrowseDaoManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
}
