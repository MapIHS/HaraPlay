import 'package:drift/drift.dart';

import '../../../features/library/domain/library_models.dart';
import '../../../features/library/domain/library_sort.dart';
import '../app_database.dart';

part 'browse_dao.g.dart';

/// Read-only library queries for the browse screens. Every query hides songs
/// shorter than [minDurationMs] (the "Hide short audio" setting).
@DriftAccessor(tables: [Songs])
class BrowseDao extends DatabaseAccessor<AppDatabase> with _$BrowseDaoMixin {
  BrowseDao(super.attachedDatabase);

  Expression<bool> _visible(int minDurationMs) =>
      songs.durationMs.isBiggerOrEqualValue(minDurationMs);

  Stream<List<SongRow>> watchSongs(
    LibrarySort<SongSortField> sort, {
    required int minDurationMs,
  }) {
    final mode = sort.descending ? OrderingMode.desc : OrderingMode.asc;
    final GeneratedColumn<Object> column = switch (sort.field) {
      SongSortField.title => songs.title,
      SongSortField.artist => songs.artist,
      SongSortField.album => songs.album,
      SongSortField.dateAdded => songs.dateAdded,
      SongSortField.duration => songs.durationMs,
      SongSortField.size => songs.sizeBytes,
    };
    final query = select(songs)
      ..where((_) => _visible(minDurationMs))
      ..orderBy([
        (_) => OrderingTerm(expression: column.isNull()),
        (_) => OrderingTerm(
          expression: column is GeneratedColumn<String>
              ? column.collate(Collate.noCase)
              : column,
          mode: mode,
        ),
        (s) => OrderingTerm(expression: s.title.collate(Collate.noCase)),
      ]);
    return query.watch();
  }

  Stream<List<AlbumSummary>> watchAlbums(
    LibrarySort<AlbumSortField> sort, {
    required int minDurationMs,
  }) => _albums(
    where: 'duration_ms >= ?',
    variables: [Variable.withInt(minDurationMs)],
    sort: sort,
  ).watch();

  /// Albums with at least one song by [artist] (null: no artist).
  Stream<List<AlbumSummary>> watchAlbumsOfArtist(
    String? artist, {
    required int minDurationMs,
  }) => _albums(
    where:
        'duration_ms >= ? AND album_id IN (SELECT album_id FROM songs '
        'WHERE ${artist == null ? 'artist IS NULL' : 'artist = ?'})',
    variables: [
      Variable.withInt(minDurationMs),
      if (artist != null) Variable.withString(artist),
    ],
    sort: const LibrarySort(AlbumSortField.year, descending: true),
  ).watch();

  Stream<AlbumSummary?> watchAlbum(int albumId, {required int minDurationMs}) =>
      _albums(
        where: 'duration_ms >= ? AND album_id = ?',
        variables: [Variable.withInt(minDurationMs), Variable.withInt(albumId)],
        sort: const LibrarySort(AlbumSortField.title),
      ).watchSingleOrNull();

  Selectable<AlbumSummary> _albums({
    required String where,
    required List<Variable> variables,
    required LibrarySort<AlbumSortField> sort,
  }) {
    final dir = sort.descending ? 'DESC' : 'ASC';
    final order = switch (sort.field) {
      AlbumSortField.title => 'g.title IS NULL, g.title COLLATE NOCASE $dir',
      AlbumSortField.artist => 'g.artist IS NULL, g.artist COLLATE NOCASE $dir',
      AlbumSortField.year => 'g.year IS NULL, g.year $dir',
      AlbumSortField.songCount => 'g.song_count $dir',
    };
    // The cover is the album's lowest song ID; its date_modified versions
    // the cached artwork.
    return customSelect(
      'SELECT g.*, c.date_modified AS cover_version FROM ('
      '  SELECT album_id, '
      '  MAX(album) AS title, '
      '  COALESCE(MAX(album_artist), '
      '    CASE WHEN COUNT(DISTINCT artist) = 1 THEN MAX(artist) END) AS artist, '
      '  MAX(album_artist) IS NULL AND COUNT(DISTINCT artist) > 1 AS various, '
      '  MAX(year) AS year, '
      '  COUNT(*) AS song_count, '
      '  SUM(duration_ms) AS duration_ms, '
      '  MIN(id) AS cover_id '
      '  FROM songs WHERE $where GROUP BY album_id'
      ') g JOIN songs c ON c.id = g.cover_id '
      'ORDER BY $order, g.title COLLATE NOCASE',
      variables: variables,
      readsFrom: {songs},
    ).map(
      (row) => AlbumSummary(
        albumId: row.readNullable<int>('album_id'),
        title: row.readNullable<String>('title'),
        artist: row.readNullable<String>('artist'),
        variousArtists: row.read<bool>('various'),
        year: row.readNullable<int>('year'),
        songCount: row.read<int>('song_count'),
        duration: Duration(milliseconds: row.read<int>('duration_ms')),
        coverSongId: row.read<int>('cover_id'),
        coverVersion: row.read<int>('cover_version'),
      ),
    );
  }

  Stream<List<ArtistSummary>> watchArtists(
    LibrarySort<ArtistSortField> sort, {
    required int minDurationMs,
  }) {
    final dir = sort.descending ? 'DESC' : 'ASC';
    final order = switch (sort.field) {
      ArtistSortField.name => 'g.name IS NULL, g.name COLLATE NOCASE $dir',
      ArtistSortField.songCount => 'g.song_count $dir',
    };
    return customSelect(
      'SELECT g.*, c.album_id AS cover_album_id, '
      'c.date_modified AS cover_version FROM ('
      '  SELECT artist AS name, COUNT(*) AS song_count, '
      '  COUNT(DISTINCT album_id) AS album_count, MIN(id) AS cover_id '
      '  FROM songs WHERE duration_ms >= ? GROUP BY artist'
      ') g JOIN songs c ON c.id = g.cover_id '
      'ORDER BY $order, g.name COLLATE NOCASE',
      variables: [Variable.withInt(minDurationMs)],
      readsFrom: {songs},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          ArtistSummary(
            name: row.readNullable<String>('name'),
            songCount: row.read<int>('song_count'),
            albumCount: row.read<int>('album_count'),
            coverSongId: row.read<int>('cover_id'),
            coverAlbumId: row.readNullable<int>('cover_album_id'),
            coverVersion: row.read<int>('cover_version'),
          ),
      ],
    );
  }

  Stream<List<FolderSummary>> watchFolders(
    LibrarySort<FolderSortField> sort, {
    required int minDurationMs,
  }) {
    final dir = sort.descending ? 'DESC' : 'ASC';
    final order = switch (sort.field) {
      FolderSortField.name => 'name COLLATE NOCASE $dir',
      FolderSortField.songCount => 'song_count $dir',
    };
    return customSelect(
      'SELECT folder_path AS path, MAX(folder_name) AS name, '
      'COUNT(*) AS song_count FROM songs WHERE duration_ms >= ? '
      'GROUP BY folder_path ORDER BY $order, path',
      variables: [Variable.withInt(minDurationMs)],
      readsFrom: {songs},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          FolderSummary(
            path: row.read<String>('path'),
            name: row.read<String>('name'),
            songCount: row.read<int>('song_count'),
          ),
      ],
    );
  }

  /// Genres with at least one song. Songs without a genre are not listed.
  Stream<List<GenreSummary>> watchGenres(
    LibrarySort<GenreSortField> sort, {
    required int minDurationMs,
  }) {
    final dir = sort.descending ? 'DESC' : 'ASC';
    final order = switch (sort.field) {
      GenreSortField.name => 'name COLLATE NOCASE $dir',
      GenreSortField.songCount => 'song_count $dir',
    };
    return customSelect(
      'SELECT genre AS name, COUNT(*) AS song_count FROM songs '
      'WHERE duration_ms >= ? AND genre IS NOT NULL '
      'GROUP BY genre ORDER BY $order, name COLLATE NOCASE',
      variables: [Variable.withInt(minDurationMs)],
      readsFrom: {songs},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          GenreSummary(
            name: row.read<String>('name'),
            songCount: row.read<int>('song_count'),
          ),
      ],
    );
  }

  /// An album's songs in disc and track order.
  Stream<List<SongRow>> watchAlbumSongs(
    int albumId, {
    required int minDurationMs,
  }) =>
      (select(songs)
            ..where((s) => s.albumId.equals(albumId) & _visible(minDurationMs))
            ..orderBy([
              (s) => OrderingTerm(expression: s.discNumber.isNull()),
              (s) => OrderingTerm(expression: s.discNumber),
              (s) => OrderingTerm(expression: s.trackNumber.isNull()),
              (s) => OrderingTerm(expression: s.trackNumber),
              (s) => OrderingTerm(expression: s.title.collate(Collate.noCase)),
            ]))
          .watch();

  /// An artist's songs grouped by album (newest first), then track order.
  Stream<List<SongRow>> watchArtistSongs(
    String? artist, {
    required int minDurationMs,
  }) =>
      (select(songs)
            ..where(
              (s) =>
                  (artist == null
                      ? s.artist.isNull()
                      : s.artist.equals(artist)) &
                  _visible(minDurationMs),
            )
            ..orderBy([
              (s) => OrderingTerm(expression: s.year.isNull()),
              (s) => OrderingTerm(expression: s.year, mode: OrderingMode.desc),
              (s) => OrderingTerm(expression: s.album.collate(Collate.noCase)),
              (s) => OrderingTerm(expression: s.discNumber),
              (s) => OrderingTerm(expression: s.trackNumber),
              (s) => OrderingTerm(expression: s.title.collate(Collate.noCase)),
            ]))
          .watch();

  Stream<List<SongRow>> watchFolderSongs(
    String folderPath, {
    required int minDurationMs,
  }) =>
      (select(songs)
            ..where(
              (s) => s.folderPath.equals(folderPath) & _visible(minDurationMs),
            )
            ..orderBy([
              (s) => OrderingTerm(expression: s.title.collate(Collate.noCase)),
            ]))
          .watch();

  Stream<List<SongRow>> watchGenreSongs(
    String genre, {
    required int minDurationMs,
  }) =>
      (select(songs)
            ..where((s) => s.genre.equals(genre) & _visible(minDurationMs))
            ..orderBy([
              (s) => OrderingTerm(expression: s.title.collate(Collate.noCase)),
            ]))
          .watch();
}
