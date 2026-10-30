// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_state_dao.dart';

// ignore_for_file: type=lint
mixin _$QueueStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $QueueStateTable get queueState => attachedDatabase.queueState;
  $SongsTable get songs => attachedDatabase.songs;
  QueueStateDaoManager get managers => QueueStateDaoManager(this);
}

class QueueStateDaoManager {
  final _$QueueStateDaoMixin _db;
  QueueStateDaoManager(this._db);
  $$QueueStateTableTableManager get queueState =>
      $$QueueStateTableTableManager(_db.attachedDatabase, _db.queueState);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
}
