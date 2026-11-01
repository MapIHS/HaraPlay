// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_info_dao.dart';

// ignore_for_file: type=lint
mixin _$AudioInfoDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
  $SongTechInfoTable get songTechInfo => attachedDatabase.songTechInfo;
  AudioInfoDaoManager get managers => AudioInfoDaoManager(this);
}

class AudioInfoDaoManager {
  final _$AudioInfoDaoMixin _db;
  AudioInfoDaoManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$SongTechInfoTableTableManager get songTechInfo =>
      $$SongTechInfoTableTableManager(_db.attachedDatabase, _db.songTechInfo);
}
