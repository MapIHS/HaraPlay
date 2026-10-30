// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_events_dao.dart';

// ignore_for_file: type=lint
mixin _$PlayEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
  $PlayEventsTable get playEvents => attachedDatabase.playEvents;
  PlayEventsDaoManager get managers => PlayEventsDaoManager(this);
}

class PlayEventsDaoManager {
  final _$PlayEventsDaoMixin _db;
  PlayEventsDaoManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$PlayEventsTableTableManager get playEvents =>
      $$PlayEventsTableTableManager(_db.attachedDatabase, _db.playEvents);
}
