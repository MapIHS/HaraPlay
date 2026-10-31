import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/playlists_dao.dart';
import 'package:haraplay/features/playlists/domain/playlist_models.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late PlaylistsDao dao;
  final at = DateTime.utc(2026, 10, 31, 12);

  setUp(() async {
    db = createTestDatabase();
    dao = db.playlistsDao;
    await db.libraryDao.applyScan([
      for (var id = 1; id <= 5; id++)
        mediaSong(id, title: 'Song $id', durationMs: 60000 * id, albumId: id),
      // Shorter than the default "Hide short audio" limit.
      mediaSong(6, title: 'Jingle', durationMs: 5000),
    ]);
  });
  tearDown(() => db.close());

  Future<List<int>> songIds(int playlistId) async => [
    for (final e in await dao.watchEntries(playlistId).first) e.song.id,
  ];

  /// Raw positions in play order.
  Future<List<int>> positions(int playlistId) async {
    final rows =
        await (db.select(db.playlistEntries)
              ..where((e) => e.playlistId.equals(playlistId))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    return [for (final r in rows) r.position];
  }

  test('create, add (duplicates allowed), summary with cover', () async {
    final id = await dao.create('Road trip', at: at);
    await dao.addSongs(id, [3, 1, 3, 6], at: at);

    expect(await songIds(id), [3, 1, 3, 6]);
    expect(await positions(id), [0, 1, 2, 3]);

    final summary = (await dao.watchPlaylist(id).first)!;
    expect(summary.name, 'Road trip');
    expect(summary.songCount, 4);
    // Short songs count too: the user put them here.
    expect(summary.duration, const Duration(milliseconds: 425000));
    expect(summary.coverSongId, 3);
    expect(summary.coverAlbumId, 3);
  });

  test('an empty playlist has no cover and zero totals', () async {
    final id = await dao.create('Empty', at: at);
    final summary = (await dao.watchPlaylist(id).first)!;
    expect(summary.songCount, 0);
    expect(summary.duration, Duration.zero);
    expect(summary.coverSongId, isNull);
  });

  test('playlists are listed by name, case-insensitively', () async {
    await dao.create('zebra', at: at);
    await dao.create('Alpha', at: at);
    await dao.create('beta', at: at);
    final names = [for (final p in await dao.watchPlaylists().first) p.name];
    expect(names, ['Alpha', 'beta', 'zebra']);
  });

  test('songs that no longer exist are skipped when adding', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 99, 2], at: at);
    expect(await songIds(id), [1, 2]);
    expect(await positions(id), [0, 1]);
  });

  test('positions stay dense after remove', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 2, 3, 4], at: at);
    final entries = await dao.watchEntries(id).first;

    final removed = (await dao.removeEntry(entries[1].entryId, at: at))!;
    expect(removed.index, 1);
    expect(removed.songId, 2);
    expect(await songIds(id), [1, 3, 4]);
    expect(await positions(id), [0, 1, 2]);
  });

  test('restoring a removed entry puts it back where it was', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 2, 3, 4], at: at);
    final entries = await dao.watchEntries(id).first;
    final removed = (await dao.removeEntry(entries[2].entryId, at: at))!;

    await dao.restoreEntry(removed, at: at);
    expect(await songIds(id), [1, 2, 3, 4]);
    expect(await positions(id), [0, 1, 2, 3]);
  });

  test('restoring after the playlist got shorter appends', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 2, 3, 4], at: at);
    var entries = await dao.watchEntries(id).first;
    final removed = (await dao.removeEntry(entries[3].entryId, at: at))!;
    entries = await dao.watchEntries(id).first;
    await dao.removeEntry(entries[0].entryId, at: at);
    await dao.removeEntry(entries[1].entryId, at: at);

    await dao.restoreEntry(removed, at: at);
    expect(await songIds(id), [3, 4]);
    expect(await positions(id), [0, 1]);
  });

  test('restore is skipped once the playlist is deleted', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1], at: at);
    final entries = await dao.watchEntries(id).first;
    final removed = (await dao.removeEntry(entries[0].entryId, at: at))!;
    await dao.deletePlaylist(id);

    await dao.restoreEntry(removed, at: at);
    expect(await db.select(db.playlistEntries).get(), isEmpty);
  });

  test('positions stay dense after reorder, both directions', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 2, 3, 4, 5], at: at);

    await dao.moveEntry(id, 0, 3, at: at);
    expect(await songIds(id), [2, 3, 4, 1, 5]);
    expect(await positions(id), [0, 1, 2, 3, 4]);

    await dao.moveEntry(id, 4, 0, at: at);
    expect(await songIds(id), [5, 2, 3, 4, 1]);
    expect(await positions(id), [0, 1, 2, 3, 4]);

    // Out of range: ignored.
    await dao.moveEntry(id, 0, 9, at: at);
    expect(await songIds(id), [5, 2, 3, 4, 1]);
  });

  test('moving one of two duplicates moves only that entry', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 2, 1], at: at);
    final before = await dao.watchEntries(id).first;

    await dao.moveEntry(id, 2, 0, at: at);
    final after = await dao.watchEntries(id).first;
    expect([for (final e in after) e.song.id], [1, 1, 2]);
    expect(after[0].entryId, before[2].entryId);
    expect(after[1].entryId, before[0].entryId);
  });

  test('gaps left by a deleted file are closed by the next edit', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 2, 3], at: at);

    // The file of song 2 disappears: the next scan drops it, and its
    // entry cascades away, leaving position 1 empty.
    await db.libraryDao.applyScan([
      for (final s in [1, 3, 4, 5]) mediaSong(s, albumId: s),
    ]);
    expect(await positions(id), [0, 2]);

    await dao.addSongs(id, [4], at: at);
    expect(await songIds(id), [1, 3, 4]);
    expect(await positions(id), [0, 1, 2]);
  });

  test('rename, and delete cascades the entries', () async {
    final id = await dao.create('Old', at: at);
    await dao.addSongs(id, [1, 2], at: at);
    final later = at.add(const Duration(minutes: 5));
    await dao.rename(id, 'New', at: later);

    final row = await (db.select(
      db.playlists,
    )..where((p) => p.id.equals(id))).getSingle();
    expect(row.name, 'New');
    expect(row.updatedAt, later.millisecondsSinceEpoch);

    await dao.deletePlaylist(id);
    expect(await dao.watchPlaylists().first, isEmpty);
    expect(await db.select(db.playlistEntries).get(), isEmpty);
  });

  test('watchPlaylistsContaining lists each playlist once', () async {
    final a = await dao.create('A', at: at);
    final b = await dao.create('B', at: at);
    await dao.create('C', at: at);
    await dao.addSongs(a, [1, 1], at: at);
    await dao.addSongs(b, [1, 2], at: at);
    expect(await dao.watchPlaylistsContaining(1).first, {a, b});
    expect(await dao.watchPlaylistsContaining(3).first, isEmpty);
  });

  test('entries follow a re-keyed song', () async {
    final id = await dao.create('P', at: at);
    await dao.addSongs(id, [1, 2], at: at);
    // MediaStore gives the same file (path of song 1) a new ID.
    await db.libraryDao.applyScan([
      mediaSong(42, path: '/storage/emulated/0/Music/song1.mp3', albumId: 1),
      mediaSong(2, albumId: 2),
    ]);
    expect(await songIds(id), [42, 2]);
  });

  group('cleanPlaylistName', () {
    test('trims and collapses whitespace', () {
      expect(cleanPlaylistName('  Late   night \n mix '), 'Late night mix');
    });
    test('rejects empty and too long names', () {
      expect(cleanPlaylistName('   '), isNull);
      expect(cleanPlaylistName('x' * (maxPlaylistNameLength + 1)), isNull);
      expect(cleanPlaylistName('x' * maxPlaylistNameLength), isNotNull);
    });
  });
}
