import 'package:drift/drift.dart';

// The library database (schema history in `AppDatabase`). Times are UTC epoch milliseconds. Every
// reference to songs.id cascades on update, so re-keying a song after a
// MediaStore ID change moves its favorites, playlist entries and history.

/// Where playback was started from; recorded with each play event.
enum PlaySource {
  songs,
  album,
  artist,
  folder,
  genre,
  playlist,
  favorites,
  search,
  queue,
  external,
}

enum RepeatSetting { off, all, one }

/// Mirror of MediaStore, merged with tag fallbacks ([SongTagFallbacks]).
@DataClassName('SongRow')
@TableIndex(name: 'songs_album_id', columns: {#albumId})
@TableIndex(name: 'songs_artist', columns: {#artist})
@TableIndex(name: 'songs_folder_path', columns: {#folderPath})
@TableIndex(name: 'songs_genre', columns: {#genre})
@TableIndex(name: 'songs_date_added', columns: {#dateAdded})
@TableIndex.sql('CREATE INDEX songs_title ON songs (title COLLATE NOCASE)')
class Songs extends Table {
  /// MediaStore `_ID`.
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  IntColumn get albumId => integer().nullable()();
  IntColumn get artistId => integer().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get durationMs => integer()();
  IntColumn get sizeBytes => integer()();
  TextColumn get mimeType => text().nullable()();

  /// Absolute file path; used to re-link a song whose MediaStore ID changed.
  TextColumn get path => text().unique()();
  TextColumn get folderPath => text()();
  TextColumn get folderName => text()();
  IntColumn get dateAdded => integer()();
  IntColumn get dateModified => integer()();

  /// Folded title, artist, album and album artist for search.
  TextColumn get searchText => text()();

  /// Artist and title were guessed from the file name (schema v2).
  BoolColumn get nameFromFilename =>
      boolean().withDefault(const Constant(false))();

  /// In a folder the user excluded (schema v5). Hidden like short audio:
  /// not in Library, Home or Search, but kept in Liked songs and playlists.
  /// Set by `LibraryDao.applyExclusions`.
  BoolColumn get excluded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FavoriteRow')
class Favorites extends Table {
  IntColumn get songId => integer().references(
    Songs,
    #id,
    onDelete: KeyAction.cascade,
    onUpdate: KeyAction.cascade,
  )();
  TextColumn get songPath => text()();
  IntColumn get addedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {songId};
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get coverSongId => integer().nullable().references(
    Songs,
    #id,
    onDelete: KeyAction.setNull,
    onUpdate: KeyAction.cascade,
  )();
}

/// Ordered songs of a playlist. The same song may appear more than once.
@DataClassName('PlaylistEntryRow')
@TableIndex(name: 'playlist_entries_order', columns: {#playlistId, #position})
class PlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId => integer().references(
    Songs,
    #id,
    onDelete: KeyAction.cascade,
    onUpdate: KeyAction.cascade,
  )();
  TextColumn get songPath => text()();
  IntColumn get position => integer()();
  IntColumn get addedAt => integer()();
}

/// Append-only listening history. Keeps a snapshot of the song's tags so
/// history and stats survive the file being deleted.
@DataClassName('PlayEventRow')
@TableIndex(name: 'play_events_started_at', columns: {#startedAt})
@TableIndex(name: 'play_events_song_id', columns: {#songId})
class PlayEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer().nullable().references(
    Songs,
    #id,
    onDelete: KeyAction.setNull,
    onUpdate: KeyAction.cascade,
  )();
  TextColumn get songPath => text()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  IntColumn get startedAt => integer()();
  IntColumn get listenedMs => integer()();
  IntColumn get durationMs => integer()();
  BoolColumn get completed => boolean()();
  TextColumn get source => textEnum<PlaySource>()();
}

/// The saved queue: a single row with `id = 1`.
@DataClassName('QueueStateRow')
class QueueState extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();

  /// JSON array of song IDs in play order.
  TextColumn get songIds => text()();

  /// JSON array of the order before shuffle; null while shuffle is off.
  TextColumn get originalSongIds => text().nullable()();
  IntColumn get currentIndex => integer()();
  IntColumn get positionMs => integer()();
  BoolColumn get shuffle => boolean()();
  TextColumn get repeatMode => textEnum<RepeatSetting>()();
  TextColumn get source => textEnum<PlaySource>()();

  /// The source's name, e.g. the album title (schema v3).
  TextColumn get sourceLabel => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Audio format details and ReplayGain tags, read from the file's header
/// when a song is played or its info opened (A5). Recreated in schema v4.
@DataClassName('SongTechInfoRow')
class SongTechInfo extends Table {
  IntColumn get songId => integer().references(
    Songs,
    #id,
    onDelete: KeyAction.cascade,
    onUpdate: KeyAction.cascade,
  )();

  /// The song's `date_modified` when the file was read. A different value
  /// means the file changed (e.g. was re-tagged) and must be read again.
  IntColumn get sourceDateModified => integer()();
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get bitDepth => integer().nullable()();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get channels => integer().nullable()();
  TextColumn get codec => text().nullable()();

  /// ReplayGain in dB, and peaks (1.0 = full scale).
  RealColumn get trackGain => real().nullable()();
  RealColumn get trackPeak => real().nullable()();
  RealColumn get albumGain => real().nullable()();
  RealColumn get albumPeak => real().nullable()();
  IntColumn get readAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {songId};
}

/// Tags read from the file itself, used where MediaStore's are missing or
/// mis-decoded. Filled by `TagEnrichmentService` in the background.
@DataClassName('SongTagFallbackRow')
class SongTagFallbacks extends Table {
  IntColumn get songId => integer().references(
    Songs,
    #id,
    onDelete: KeyAction.cascade,
    onUpdate: KeyAction.cascade,
  )();

  /// The song's `date_modified` when the file was read. A different value
  /// means the file changed and must be read again.
  IntColumn get sourceDateModified => integer()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();

  /// The file could not be parsed; not retried until it changes.
  BoolColumn get failed => boolean()();
  IntColumn get readAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {songId};
}
