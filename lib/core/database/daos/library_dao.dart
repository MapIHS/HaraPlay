import 'package:drift/drift.dart';

import '../../../features/library/data/filename_tags.dart';
import '../../../features/library/data/tag_merge.dart';
import '../../platform/media_store_song.dart';
import '../../utils/text_normalize.dart';
import '../app_database.dart';

part 'library_dao.g.dart';

/// What one library sync changed.
class SyncResult {
  const SyncResult({
    required this.added,
    required this.updated,
    required this.removed,
    required this.rekeyed,
    required this.total,
  });

  final int added;
  final int updated;
  final int removed;

  /// Songs whose MediaStore ID changed and were moved to the new ID.
  final int rekeyed;

  /// Songs in the library after the sync.
  final int total;

  bool get changedAnything =>
      added > 0 || updated > 0 || removed > 0 || rekeyed > 0;

  @override
  String toString() =>
      'SyncResult(+$added ~$updated -$removed rekeyed $rekeyed = $total)';
}

/// Song, album and folder counts, respecting the minimum-duration filter.
class LibraryCounts {
  const LibraryCounts({
    required this.songs,
    required this.albums,
    required this.folders,
    required this.totalDuration,
  });

  static const empty = LibraryCounts(
    songs: 0,
    albums: 0,
    folders: 0,
    totalDuration: Duration.zero,
  );

  final int songs;
  final int albums;
  final int folders;
  final Duration totalDuration;
}

/// A file's tags as read by `audio_metadata_reader`, or a failed read.
class FileTagsResult {
  const FileTagsResult.read(this.tags) : failed = false;
  const FileTagsResult.failed() : tags = const SongTags(), failed = true;

  final SongTags tags;
  final bool failed;
}

@DriftAccessor(tables: [Songs, SongTagFallbacks])
class LibraryDao extends DatabaseAccessor<AppDatabase> with _$LibraryDaoMixin {
  LibraryDao(super.attachedDatabase);

  /// Mirrors [scanned] into the songs table in one transaction
  /// (docs/PLAN.md §6, sync rules).
  Future<SyncResult> applyScan(List<MediaStoreSong> scanned) => transaction(
    () async {
      final incomingById = {for (final s in scanned) s.id: s};
      final incomingIdByPath = {
        for (final s in incomingById.values) s.path: s.id,
      };
      final existing = await select(songs).get();
      final existingPaths = {for (final row in existing) row.path};

      // 1. Classify every stored song.
      final gone = <int>[];
      final rekeys = <int, int>{}; // old ID → new ID
      for (final row in existing) {
        final idForPath = incomingIdByPath[row.path];
        if (idForPath != null) {
          if (idForPath != row.id) rekeys[row.id] = idForPath;
          continue;
        }
        // Same ID, new path: the file was renamed or moved. Unless that
        // path belongs to another stored song, which then takes this ID.
        final sameId = incomingById[row.id];
        if (sameId != null && !existingPaths.contains(sameId.path)) continue;
        gone.add(row.id);
      }

      // 2. Delete what is gone; cascades remove favorites and entries.
      if (gone.isNotEmpty) {
        await (delete(songs)..where((s) => s.id.isIn(gone))).go();
      }

      // 3. Re-key in two phases so swapped IDs never collide. Child rows
      //    follow through ON UPDATE CASCADE.
      for (final oldId in rekeys.keys) {
        await _updateSongId(oldId, -oldId);
      }
      for (final MapEntry(key: oldId, value: newId) in rekeys.entries) {
        await _updateSongId(-oldId, newId);
      }

      // 4. Upsert, merged with still-valid tag fallbacks; skip unchanged rows.
      final stored = {
        for (final row in existing)
          if (!gone.contains(row.id)) (rekeys[row.id] ?? row.id): row,
      };
      final fallbacks = {
        for (final f in await select(songTagFallbacks).get()) f.songId: f,
      };
      var added = 0;
      var updated = 0;
      final toWrite = <SongRow>[];
      final rows = withMergedAlbumIds([
        for (final song in incomingById.values)
          songRowFrom(
            song,
            fileTags: switch (fallbacks[song.id]) {
              final f?
                  when !f.failed &&
                      f.sourceDateModified ==
                          song.dateModified.millisecondsSinceEpoch =>
                tagsOfFallback(f),
              _ => null,
            },
          ),
      ]);
      for (final row in rows) {
        final before = stored[row.id];
        if (before == null) {
          added++;
        } else if (before.copyWith(id: row.id) != row) {
          updated++;
        } else {
          continue;
        }
        toWrite.add(row);
      }
      // toCompanion(false) writes nulls explicitly, so a tag that was
      // removed from a file is cleared instead of silently kept.
      await batch(
        (b) => b.insertAllOnConflictUpdate(songs, [
          for (final row in toWrite) row.toCompanion(false),
        ]),
      );

      return SyncResult(
        added: added,
        updated: updated,
        removed: gone.length,
        rekeyed: rekeys.length,
        total: incomingById.length,
      );
    },
  );

  Future<void> _updateSongId(int from, int to) => (update(
    songs,
  )..where((s) => s.id.equals(from))).write(SongsCompanion(id: Value(to)));

  /// Songs whose file tags should be read (§6.1): no valid fallback yet,
  /// and something missing or possibly mis-decoded.
  Future<List<SongRow>> enrichmentCandidates() async {
    final query = select(songs).join([
      leftOuterJoin(
        songTagFallbacks,
        songTagFallbacks.songId.equalsExp(songs.id) &
            songTagFallbacks.sourceDateModified.equalsExp(songs.dateModified),
      ),
    ])..where(songTagFallbacks.songId.isNull());
    final rows = await query.map((r) => r.readTable(songs)).get();
    return [
      for (final row in rows)
        if (needsFileTags(tagsOfRow(row))) row,
    ];
  }

  /// Stores file-tag results and merges them into the songs they belong to.
  Future<void> saveFileTags(
    List<(SongRow, FileTagsResult)> results, {
    required DateTime readAt,
  }) => transaction(() async {
    for (final (song, result) in results) {
      // The song may have been removed or changed since it was read.
      final current = await (select(
        songs,
      )..where((s) => s.id.equals(song.id))).getSingleOrNull();
      if (current == null || current.dateModified != song.dateModified) {
        continue;
      }
      final file = result.tags;
      await into(songTagFallbacks).insertOnConflictUpdate(
        SongTagFallbackRow(
          songId: song.id,
          sourceDateModified: song.dateModified,
          year: file.year,
          trackNumber: file.trackNumber,
          discNumber: file.discNumber,
          genre: file.genre,
          albumArtist: file.albumArtist,
          title: file.title,
          artist: file.artist,
          album: file.album,
          failed: result.failed,
          readAt: readAt.millisecondsSinceEpoch,
        ),
      );
      if (result.failed) continue;
      // Undo an earlier file-name guess first, so real file tags win.
      final mediaStore = mediaStoreTagsOfRow(current);
      final merged = withTags(
        current,
        mergeTagsForPath(mediaStore, file, current.path),
      );
      if (merged != current) {
        await update(songs).replace(merged.toCompanion(false));
      }
    }
    await _mergeAlbumIds();
  });

  /// The SQL form of [withMergedAlbumIds], for after the tag pass renamed
  /// albums in place.
  Future<void> _mergeAlbumIds() => customUpdate(
    'UPDATE songs SET album_id = ('
    '  SELECT MIN(s2.album_id) FROM songs s2 '
    '  WHERE s2.folder_path = songs.folder_path '
    '  AND s2.album = songs.album COLLATE NOCASE'
    ') WHERE album IS NOT NULL AND album_id IS NOT NULL',
    updates: {songs},
    updateKind: UpdateKind.update,
  );

  /// Marks the songs in [folders] (and their subfolders) as excluded and
  /// clears the mark everywhere else. Only changed rows are written, so
  /// unchanged queries stay quiet.
  Future<void> applyExclusions(List<String> folders) {
    // A prefix match on "folder/" (not LIKE, whose wildcards can appear in
    // folder names).
    final inside = folders.isEmpty
        ? '0'
        : List.filled(
            folders.length,
            '(folder_path = ? OR substr(folder_path, 1, length(?) + 1) = ? || \'/\')',
          ).join(' OR ');
    return customUpdate(
      'UPDATE songs SET excluded = ($inside) WHERE excluded != ($inside)',
      variables: [
        for (var pass = 0; pass < 2; pass++)
          for (final folder in folders) ...[
            Variable.withString(folder),
            Variable.withString(folder),
            Variable.withString(folder),
          ],
      ],
      updates: {songs},
      updateKind: UpdateKind.update,
    );
  }

  /// Every folder that directly holds songs, with its song count (all
  /// songs, whatever the filters), for the excluded-folders picker.
  Future<Map<String, int>> songFolders() async {
    final rows = await customSelect(
      'SELECT folder_path, COUNT(*) AS n FROM songs GROUP BY folder_path',
      readsFrom: {songs},
    ).get();
    return {
      for (final r in rows) r.read<String>('folder_path'): r.read<int>('n'),
    };
  }

  Selectable<LibraryCounts> _counts(int minDurationMs) =>
      customSelect(
        'SELECT COUNT(*) AS songs, '
        'COUNT(DISTINCT album_id) AS albums, '
        'COUNT(DISTINCT folder_path) AS folders, '
        'COALESCE(SUM(duration_ms), 0) AS total_ms '
        'FROM songs WHERE duration_ms >= ? AND excluded = 0',
        variables: [Variable.withInt(minDurationMs)],
        readsFrom: {songs},
      ).map(
        (r) => LibraryCounts(
          songs: r.read<int>('songs'),
          albums: r.read<int>('albums'),
          folders: r.read<int>('folders'),
          totalDuration: Duration(milliseconds: r.read<int>('total_ms')),
        ),
      );

  Future<LibraryCounts> counts({required int minDurationMs}) =>
      _counts(minDurationMs).getSingle();

  Stream<LibraryCounts> watchCounts({required int minDurationMs}) =>
      _counts(minDurationMs).watchSingle();

  /// Every song with its fallback row, if any (debug screen).
  Stream<List<(SongRow, SongTagFallbackRow?)>> watchSongsWithFallbacks() {
    final query = select(songs).join(
      [
        leftOuterJoin(
          songTagFallbacks,
          songTagFallbacks.songId.equalsExp(songs.id),
        ),
      ],
    )..orderBy([OrderingTerm(expression: songs.title.collate(Collate.noCase))]);
    return query
        .map((r) => (r.readTable(songs), r.readTableOrNull(songTagFallbacks)))
        .watch();
  }
}

/// [rows] with one album ID per album: songs in the same folder whose album
/// names match (ignoring case) share the lowest of their IDs. MediaStore
/// splits an album when one file's tags were decoded differently (e.g. a
/// Latin-1 tag), even after the tag pass fixed the name.
List<SongRow> withMergedAlbumIds(List<SongRow> rows) {
  final lowest = <(String, String), int>{};
  for (final row in rows) {
    final album = row.album;
    final id = row.albumId;
    if (album == null || id == null) continue;
    final key = (row.folderPath, album.toLowerCase());
    final current = lowest[key];
    if (current == null || id < current) lowest[key] = id;
  }
  return [
    for (final row in rows)
      switch ((row.album, row.albumId)) {
        (final album?, final _?) => row.copyWith(
          albumId: Value(lowest[(row.folderPath, album.toLowerCase())]),
        ),
        _ => row,
      },
  ];
}

/// The songs-table row for a MediaStore song, merged with [fileTags].
SongRow songRowFrom(MediaStoreSong song, {SongTags? fileTags}) {
  final mediaStoreTags = SongTags(
    title: song.title,
    artist: song.artist,
    album: song.album,
    albumArtist: song.albumArtist,
    genre: song.genre,
    trackNumber: song.trackNumber,
    discNumber: song.discNumber,
    year: song.year,
  );
  final merged = fileTags == null
      ? mediaStoreTags
      : mergeTagsForPath(mediaStoreTags, fileTags, song.path);
  final (tags, fromFilename) = withFilenameTags(merged, song.path);
  return SongRow(
    id: song.id,
    title: tags.title ?? song.title,
    artist: tags.artist,
    album: tags.album,
    albumArtist: tags.albumArtist,
    albumId: song.albumId,
    artistId: song.artistId,
    genre: tags.genre,
    trackNumber: tags.trackNumber,
    discNumber: tags.discNumber,
    year: tags.year,
    durationMs: song.duration.inMilliseconds,
    sizeBytes: song.sizeBytes,
    // Set from the excluded folders right after the scan, in the same
    // transaction (LibrarySyncService).
    excluded: false,
    mimeType: song.mimeType,
    path: song.path,
    folderPath: song.folderPath,
    folderName: song.folderName,
    dateAdded: song.dateAdded.millisecondsSinceEpoch,
    dateModified: song.dateModified.millisecondsSinceEpoch,
    searchText: _searchText(tags, song.title),
    nameFromFilename: fromFilename,
  );
}

SongTags tagsOfRow(SongRow row) => SongTags(
  title: row.title,
  artist: row.artist,
  album: row.album,
  albumArtist: row.albumArtist,
  genre: row.genre,
  trackNumber: row.trackNumber,
  discNumber: row.discNumber,
  year: row.year,
);

SongTags tagsOfFallback(SongTagFallbackRow row) => SongTags(
  title: row.title,
  artist: row.artist,
  album: row.album,
  albumArtist: row.albumArtist,
  genre: row.genre,
  trackNumber: row.trackNumber,
  discNumber: row.discNumber,
  year: row.year,
);

/// [row]'s tags as MediaStore reported them, i.e. without a file-name guess.
SongTags mediaStoreTagsOfRow(SongRow row) {
  final tags = tagsOfRow(row);
  if (!row.nameFromFilename) return tags;
  return SongTags(
    title: fileStem(row.path),
    album: tags.album,
    albumArtist: tags.albumArtist,
    genre: tags.genre,
    trackNumber: tags.trackNumber,
    discNumber: tags.discNumber,
    year: tags.year,
  );
}

/// [row] with its tag fields replaced by [tags], then the file-name guess
/// applied if still needed, and the search text rebuilt.
SongRow withTags(SongRow row, SongTags merged) {
  final (tags, fromFilename) = withFilenameTags(merged, row.path);
  return row.copyWith(
    nameFromFilename: fromFilename,
    title: tags.title ?? row.title,
    artist: Value(tags.artist),
    album: Value(tags.album),
    albumArtist: Value(tags.albumArtist),
    genre: Value(tags.genre),
    trackNumber: Value(tags.trackNumber),
    discNumber: Value(tags.discNumber),
    year: Value(tags.year),
    searchText: _searchText(tags, row.title),
  );
}

String _searchText(SongTags tags, String fallbackTitle) => buildSearchText([
  tags.title ?? fallbackTitle,
  tags.artist,
  tags.album,
  tags.albumArtist,
]);
