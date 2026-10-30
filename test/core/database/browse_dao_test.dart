import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/browse_dao.dart';
import 'package:haraplay/features/library/domain/library_sort.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BrowseDao browse;

  setUp(() async {
    db = createTestDatabase();
    browse = db.browseDao;
    await db.libraryDao.applyScan([
      // Album 10: one artist, years on some tracks.
      mediaSong(
        1,
        title: 'b-side',
        artist: 'Mono Lisa',
        album: 'Night Drive',
        albumId: 10,
        year: 2019,
        track: 2,
        path: '/m/nd/2.ogg',
      ),
      mediaSong(
        2,
        title: 'Opener',
        artist: 'Mono Lisa',
        album: 'Night Drive',
        albumId: 10,
        track: 1,
        genre: 'Synthwave',
        path: '/m/nd/1.ogg',
      ),
      // Album 20: a compilation without an album-artist tag.
      mediaSong(
        3,
        title: 'Alpha',
        artist: 'Kai Tone',
        album: 'Double Feature',
        albumId: 20,
        track: 2001,
        genre: 'Jazz',
        path: '/m/df/a.m4a',
      ),
      mediaSong(
        4,
        title: 'Beta',
        artist: 'Ana Sine',
        album: 'Double Feature',
        albumId: 20,
        track: 2002,
        genre: 'Jazz',
        path: '/m/df/b.m4a',
      ),
      // Album 30: tagged album artist.
      mediaSong(
        5,
        title: 'Gamma',
        artist: 'Kai Tone',
        album: 'Saffron',
        albumArtist: 'The Test Tones',
        albumId: 30,
        path: '/m/s/g.mp3',
      ),
      // No tags, and a short clip.
      mediaSong(6, title: 'zz untitled', albumId: 40, path: '/m/u/x.wav'),
      mediaSong(
        7,
        title: 'Jingle',
        artist: 'Kai Tone',
        albumId: 30,
        durationMs: 10000,
        path: '/m/s/j.mp3',
      ),
    ]);
  });
  tearDown(() => db.close());

  const minMs = 30000;

  test('songs sort with missing values last, both directions', () async {
    final byArtist = await browse
        .watchSongs(
          const LibrarySort(SongSortField.artist),
          minDurationMs: minMs,
        )
        .first;
    expect(byArtist.map((s) => s.artist), [
      'Ana Sine',
      'Kai Tone',
      'Kai Tone',
      'Mono Lisa',
      'Mono Lisa',
      null,
    ]);
    final desc = await browse
        .watchSongs(
          const LibrarySort(SongSortField.artist, descending: true),
          minDurationMs: minMs,
        )
        .first;
    expect(desc.first.artist, 'Mono Lisa');
    expect(desc.last.artist, isNull);
  });

  test('short songs are hidden everywhere', () async {
    final songs = await browse
        .watchSongs(
          const LibrarySort(SongSortField.title),
          minDurationMs: minMs,
        )
        .first;
    expect(songs.map((s) => s.title), isNot(contains('Jingle')));
    final all = await browse
        .watchSongs(const LibrarySort(SongSortField.title), minDurationMs: 0)
        .first;
    expect(all, hasLength(7));
  });

  test('albums group by album ID with the right artist label', () async {
    final albums = await browse
        .watchAlbums(
          const LibrarySort(AlbumSortField.title),
          minDurationMs: minMs,
        )
        .first;
    expect(albums.map((a) => a.title), [
      'Double Feature',
      'Night Drive',
      'Saffron',
      null,
    ]);
    final compilation = albums[0];
    expect(compilation.artist, isNull);
    expect(compilation.variousArtists, isTrue);
    final nightDrive = albums[1];
    expect(nightDrive.artist, 'Mono Lisa');
    expect(nightDrive.year, 2019);
    expect(nightDrive.songCount, 2);
    expect(nightDrive.coverSongId, 1);
    expect(albums[2].artist, 'The Test Tones');
    expect(albums[2].songCount, 1); // the jingle is hidden
  });

  test('album songs are in disc and track order', () async {
    final songs = await browse.watchAlbumSongs(20, minDurationMs: minMs).first;
    expect(songs.map((s) => (s.discNumber, s.trackNumber)), [(2, 1), (2, 2)]);
    final nd = await browse.watchAlbumSongs(10, minDurationMs: minMs).first;
    expect(nd.map((s) => s.title), ['Opener', 'b-side']);
  });

  test('artists include an unknown group, sorted last', () async {
    final artists = await browse
        .watchArtists(
          const LibrarySort(ArtistSortField.name),
          minDurationMs: minMs,
        )
        .first;
    expect(artists.map((a) => (a.name, a.songCount)), [
      ('Ana Sine', 1),
      ('Kai Tone', 2),
      ('Mono Lisa', 2),
      (null, 1),
    ]);
    final kai = artists[1];
    expect(kai.albumCount, 2);

    final unknownSongs = await browse
        .watchArtistSongs(null, minDurationMs: minMs)
        .first;
    expect(unknownSongs.single.title, 'zz untitled');
    final kaiAlbums = await browse
        .watchAlbumsOfArtist('Kai Tone', minDurationMs: minMs)
        .first;
    expect(
      kaiAlbums.map((a) => a.title),
      unorderedEquals(['Double Feature', 'Saffron']),
    );
  });

  test('folders and genres', () async {
    final folders = await browse
        .watchFolders(
          const LibrarySort(FolderSortField.songCount, descending: true),
          minDurationMs: minMs,
        )
        .first;
    expect(folders.first.songCount, 2);
    expect(folders.map((f) => f.name), containsAll(['nd', 'df', 's', 'u']));

    final genres = await browse
        .watchGenres(
          const LibrarySort(GenreSortField.name),
          minDurationMs: minMs,
        )
        .first;
    expect(genres.map((g) => (g.name, g.songCount)), [
      ('Jazz', 2),
      ('Synthwave', 1),
    ]);
    final jazz = await browse
        .watchGenreSongs('Jazz', minDurationMs: minMs)
        .first;
    expect(jazz, hasLength(2));
  });

  test('sort encoding round-trips', () {
    const sort = LibrarySort(SongSortField.dateAdded, descending: true);
    expect(LibrarySort.decode(sort.encode(), SongSortField.values), sort);
    expect(LibrarySort.decode('nope:asc', SongSortField.values), isNull);
  });
}
