import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/platform/media_store_song.dart';

/// A fresh in-memory database with foreign keys on. Streams close
/// synchronously, so widget tests don't end with drift's close timer pending.
AppDatabase createTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

/// A MediaStore song for sync tests.
MediaStoreSong mediaSong(
  int id, {
  String? path,
  String? title,
  String? artist,
  String? album,
  String? genre,
  String? albumArtist,
  int albumId = 1,
  int? year,
  int track = 0,
  int durationMs = 180000,
  int modifiedSec = 1700000000,
}) => MediaStoreSong.tryParse({
  'id': id,
  'path': path ?? '/storage/emulated/0/Music/song$id.mp3',
  'title': title ?? 'Song $id',
  'artist': artist,
  'album': album,
  'genre': genre,
  'albumArtist': albumArtist,
  'year': year,
  'track': track,
  'durationMs': durationMs,
  'albumId': albumId,
  'dateAddedSec': 1700000000,
  'dateModifiedSec': modifiedSec,
})!;
