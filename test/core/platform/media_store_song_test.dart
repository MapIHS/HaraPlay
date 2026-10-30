import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/platform/media_store_song.dart';

void main() {
  final fullRow = <Object?, Object?>{
    'id': 42,
    'title': '  Golden Hour ',
    'artist': 'The Saffrons',
    'album': 'Warm Light',
    'albumArtist': 'Various Artists',
    'albumId': 7,
    'artistId': 3,
    'genre': 'Indie',
    'track': 2005,
    'year': 2021,
    'durationMs': 215000,
    'sizeBytes': 5242880,
    'mimeType': 'audio/mpeg',
    'path': '/storage/emulated/0/Music/Warm Light/05 Golden Hour.mp3',
    'dateAddedSec': 1700000000,
    'dateModifiedSec': 1700000500,
  };

  test('parses a complete row', () {
    final song = MediaStoreSong.tryParse(fullRow)!;

    expect(song.id, 42);
    expect(song.title, 'Golden Hour');
    expect(song.artist, 'The Saffrons');
    expect(song.albumArtist, 'Various Artists');
    expect(song.albumId, 7);
    expect(song.genre, 'Indie');
    expect(song.discNumber, 2);
    expect(song.trackNumber, 5);
    expect(song.year, 2021);
    expect(song.duration, const Duration(seconds: 215));
    expect(song.sizeBytes, 5242880);
    expect(song.folderPath, '/storage/emulated/0/Music/Warm Light');
    expect(song.folderName, 'Warm Light');
    expect(song.dateAdded, DateTime.utc(2023, 11, 14, 22, 13, 20));
    expect(song.dateAdded.isUtc, isTrue);
  });

  test('turns MediaStore placeholders and blanks into null', () {
    final song = MediaStoreSong.tryParse({
      ...fullRow,
      'artist': '<unknown>',
      'album': '   ',
      'genre': null,
      'year': 0,
      'track': 0,
    })!;

    expect(song.artist, isNull);
    expect(song.album, isNull);
    expect(song.genre, isNull);
    expect(song.year, isNull);
    expect(song.trackNumber, isNull);
    expect(song.discNumber, isNull);
  });

  test('a plain track number has no disc', () {
    final song = MediaStoreSong.tryParse({...fullRow, 'track': 9})!;
    expect(song.trackNumber, 9);
    expect(song.discNumber, isNull);
  });

  test('falls back to the file name when the title is missing', () {
    final song = MediaStoreSong.tryParse({...fullRow, 'title': null})!;
    expect(song.title, '05 Golden Hour');
  });

  test('rejects rows without an id or path', () {
    expect(MediaStoreSong.tryParse({...fullRow, 'id': null}), isNull);
    expect(MediaStoreSong.tryParse({...fullRow, 'path': ''}), isNull);
  });

  test('tolerates missing optional values', () {
    final song = MediaStoreSong.tryParse({'id': 1, 'path': '/a.flac'})!;
    expect(song.title, 'a');
    expect(song.folderPath, '/');
    expect(song.duration, Duration.zero);
    expect(song.dateAdded, DateTime.utc(1970));
  });
}
