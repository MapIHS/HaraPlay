import 'package:drift/drift.dart';

import '../../../features/playlists/domain/playlist_models.dart';
import '../app_database.dart';

part 'playlists_dao.g.dart';

/// User playlists. Entry positions are kept dense (0..n-1): every edit
/// renumbers the playlist, which also closes the gaps left when a song's
/// file is deleted and its entries cascade away.
@DriftAccessor(tables: [Playlists, PlaylistEntries, Songs])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(super.attachedDatabase);

  /// All playlists by name.
  Stream<List<PlaylistSummary>> watchPlaylists() =>
      _summaries(where: '1').watch();

  Stream<PlaylistSummary?> watchPlaylist(int id) => _summaries(
    where: 'p.id = ?',
    variables: [Variable.withInt(id)],
  ).watchSingleOrNull();

  Selectable<PlaylistSummary> _summaries({
    required String where,
    List<Variable> variables = const [],
  }) =>
      customSelect(
        'SELECT g.*, c.album_id AS cover_album_id, '
        'c.date_modified AS cover_version FROM ('
        '  SELECT p.id, p.name, COUNT(s.id) AS song_count, '
        '  COALESCE(SUM(s.duration_ms), 0) AS duration_ms, '
        '  (SELECT e2.song_id FROM playlist_entries e2 '
        '   WHERE e2.playlist_id = p.id ORDER BY e2.position, e2.id LIMIT 1) '
        '  AS cover_id '
        '  FROM playlists p '
        '  LEFT JOIN playlist_entries e ON e.playlist_id = p.id '
        '  LEFT JOIN songs s ON s.id = e.song_id '
        '  WHERE $where GROUP BY p.id'
        ') g LEFT JOIN songs c ON c.id = g.cover_id '
        'ORDER BY g.name COLLATE NOCASE, g.id',
        variables: variables,
        readsFrom: {playlists, playlistEntries, songs},
      ).map(
        (row) => PlaylistSummary(
          id: row.read<int>('id'),
          name: row.read<String>('name'),
          songCount: row.read<int>('song_count'),
          duration: Duration(milliseconds: row.read<int>('duration_ms')),
          coverSongId: row.readNullable<int>('cover_id'),
          coverAlbumId: row.readNullable<int>('cover_album_id'),
          coverVersion: row.readNullable<int>('cover_version'),
        ),
      );

  /// A playlist's songs in order.
  Stream<List<PlaylistEntry>> watchEntries(int playlistId) {
    final query =
        select(
            playlistEntries,
          ).join([innerJoin(songs, songs.id.equalsExp(playlistEntries.songId))])
          ..where(playlistEntries.playlistId.equals(playlistId))
          ..orderBy([
            OrderingTerm.asc(playlistEntries.position),
            OrderingTerm.asc(playlistEntries.id),
          ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PlaylistEntry(
            entryId: row.readTable(playlistEntries).id,
            song: row.readTable(songs),
          ),
      ],
    );
  }

  /// Every song's path by ID, hidden songs included (`.m3u` import).
  Future<Map<int, String>> songPaths() async {
    final query = selectOnly(songs)..addColumns([songs.id, songs.path]);
    return {
      for (final row in await query.get())
        row.read(songs.id)!: row.read(songs.path)!,
    };
  }

  /// IDs of the playlists that contain [songId] (add-to-playlist sheet).
  Stream<Set<int>> watchPlaylistsContaining(int songId) {
    final query = selectOnly(playlistEntries, distinct: true)
      ..addColumns([playlistEntries.playlistId])
      ..where(playlistEntries.songId.equals(songId));
    return query.watch().map(
      (rows) => {for (final row in rows) row.read(playlistEntries.playlistId)!},
    );
  }

  /// Creates a playlist named [name] (already cleaned) and returns its ID.
  Future<int> create(String name, {required DateTime at}) =>
      into(playlists).insert(
        PlaylistsCompanion.insert(
          name: name,
          createdAt: at.millisecondsSinceEpoch,
          updatedAt: at.millisecondsSinceEpoch,
        ),
      );

  Future<void> rename(int id, String name, {required DateTime at}) =>
      (update(playlists)..where((p) => p.id.equals(id))).write(
        PlaylistsCompanion(
          name: Value(name),
          updatedAt: Value(at.millisecondsSinceEpoch),
        ),
      );

  /// Deletes the playlist; its entries cascade.
  Future<void> deletePlaylist(int id) =>
      (delete(playlists)..where((p) => p.id.equals(id))).go();

  /// Appends [songIds] in order. Duplicates are allowed; IDs of songs that
  /// no longer exist are skipped.
  Future<void> addSongs(
    int playlistId,
    List<int> songIds, {
    required DateTime at,
  }) => transaction(() async {
    final ids = await _orderedEntryIds(playlistId);
    await _renumber(ids);
    final paths = <int, String>{};
    for (var i = 0; i < songIds.length; i += 500) {
      final chunk = songIds.sublist(i, (i + 500).clamp(0, songIds.length));
      final query = selectOnly(songs)
        ..addColumns([songs.id, songs.path])
        ..where(songs.id.isIn(chunk));
      for (final row in await query.get()) {
        paths[row.read(songs.id)!] = row.read(songs.path)!;
      }
    }
    var position = ids.length;
    await batch((b) {
      for (final songId in songIds) {
        final path = paths[songId];
        if (path == null) continue;
        b.insert(
          playlistEntries,
          PlaylistEntriesCompanion.insert(
            playlistId: playlistId,
            songId: songId,
            songPath: path,
            position: position++,
            addedAt: at.millisecondsSinceEpoch,
          ),
        );
      }
    });
    await _touch(playlistId, at);
  });

  /// Removes one entry and returns what [restoreEntry] needs to undo it.
  Future<RemovedEntry?> removeEntry(int entryId, {required DateTime at}) =>
      transaction(() async {
        final entry = await (select(
          playlistEntries,
        )..where((e) => e.id.equals(entryId))).getSingleOrNull();
        if (entry == null) return null;
        final ids = await _orderedEntryIds(entry.playlistId);
        final index = ids.indexOf(entryId);
        await (delete(
          playlistEntries,
        )..where((e) => e.id.equals(entryId))).go();
        await _renumber(ids..removeAt(index));
        await _touch(entry.playlistId, at);
        return RemovedEntry(
          playlistId: entry.playlistId,
          songId: entry.songId,
          songPath: entry.songPath,
          index: index,
          addedAt: entry.addedAt,
        );
      });

  /// Puts a removed entry back at its old index (or at the end, if the
  /// playlist got shorter since). Skipped if the playlist or song is gone.
  Future<void> restoreEntry(RemovedEntry removed, {required DateTime at}) =>
      transaction(() async {
        final playlistExists = await (select(
          playlists,
        )..where((p) => p.id.equals(removed.playlistId))).getSingleOrNull();
        final songExists = await (select(
          songs,
        )..where((s) => s.id.equals(removed.songId))).getSingleOrNull();
        if (playlistExists == null || songExists == null) return;
        final ids = await _orderedEntryIds(removed.playlistId);
        final entryId = await into(playlistEntries).insert(
          PlaylistEntriesCompanion.insert(
            playlistId: removed.playlistId,
            songId: removed.songId,
            songPath: removed.songPath,
            position: ids.length,
            addedAt: removed.addedAt,
          ),
        );
        await _renumber(
          ids..insert(removed.index.clamp(0, ids.length), entryId),
        );
        await _touch(removed.playlistId, at);
      });

  /// Moves the entry at index [from] to index [to] (indices in the order
  /// before the move).
  Future<void> moveEntry(
    int playlistId,
    int from,
    int to, {
    required DateTime at,
  }) => transaction(() async {
    final ids = await _orderedEntryIds(playlistId);
    if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) return;
    if (from != to) ids.insert(to, ids.removeAt(from));
    await _renumber(ids);
    await _touch(playlistId, at);
  });

  Future<List<int>> _orderedEntryIds(int playlistId) async {
    final query = selectOnly(playlistEntries)
      ..addColumns([playlistEntries.id])
      ..where(playlistEntries.playlistId.equals(playlistId))
      ..orderBy([
        OrderingTerm.asc(playlistEntries.position),
        OrderingTerm.asc(playlistEntries.id),
      ]);
    return [for (final row in await query.get()) row.read(playlistEntries.id)!];
  }

  /// Sets each entry's position to its index in [entryIds].
  Future<void> _renumber(List<int> entryIds) async {
    for (var i = 0; i < entryIds.length; i++) {
      await customUpdate(
        'UPDATE playlist_entries SET position = ? '
        'WHERE id = ? AND position != ?',
        variables: [
          Variable.withInt(i),
          Variable.withInt(entryIds[i]),
          Variable.withInt(i),
        ],
        updates: {playlistEntries},
      );
    }
  }

  Future<void> _touch(int playlistId, DateTime at) =>
      (update(playlists)..where((p) => p.id.equals(playlistId))).write(
        PlaylistsCompanion(updatedAt: Value(at.millisecondsSinceEpoch)),
      );
}
