import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/platform/media_store_channel.dart';
import 'package:haraplay/core/platform/media_store_song.dart';

const _longKeys = [
  'id',
  'albumId',
  'artistId',
  'track',
  'year',
  'durationMs',
  'sizeBytes',
  'dateAddedSec',
  'dateModifiedSec',
];
const _sharedKeys = ['artist', 'album', 'albumArtist', 'genre', 'mimeType'];
const _noValue = -9223372036854775808;

/// Builds the column-wise reply the way `MediaStoreQueries.kt` does.
Map<String, Object?> columnsReply(List<Map<String, Object?>> rows) {
  final strings = <String>[];
  final ids = <String, int>{};
  int intern(Object? value) => value is String
      ? ids.putIfAbsent(value, () {
          strings.add(value);
          return strings.length - 1;
        })
      : -1;
  final folders = <int>[];
  final fileNames = <String?>[];
  for (final row in rows) {
    final path = row['path'] as String?;
    final slash = path?.lastIndexOf('/') ?? -1;
    if (path == null || slash < 0) {
      folders.add(-1);
      fileNames.add(path);
    } else {
      folders.add(intern(path.substring(0, slash)));
      fileNames.add(path.substring(slash + 1));
    }
  }
  return {
    'count': rows.length,
    'noValue': _noValue,
    'strings': strings,
    'longs': {
      for (final key in _longKeys)
        key: Int64List.fromList([
          for (final row in rows) (row[key] as int?) ?? _noValue,
        ]),
    },
    'shared': {
      for (final key in _sharedKeys)
        key: Int32List.fromList([for (final row in rows) intern(row[key])]),
    },
    'folders': Int32List.fromList(folders),
    'titles': [for (final row in rows) row['title']],
    'fileNames': fileNames,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('haraplay/media');
  final calls = <String>[];

  void mockPlatform({required int sdkInt}) {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'sdkInt' => sdkInt,
            'querySongs' => columnsReply([
              {
                'id': 1,
                'path': '/m/a.mp3',
                'genre': sdkInt >= 30 ? 'Rock' : null,
              },
              {'id': 2, 'path': '/m/b.mp3'},
              {'id': null, 'path': '/m/broken.mp3'},
            ]),
            'queryGenreMembership' => {
              'Jazz': [1, 2],
              'Blues': [2],
            },
            _ => null,
          };
        });
  }

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('API 30+: reads genres from the song rows only', () async {
    mockPlatform(sdkInt: 34);
    final songs = await MediaStoreChannel().querySongs();

    expect(songs.map((s) => s.id), [1, 2]);
    expect(songs.first.genre, 'Rock');
    expect(calls, isNot(contains('queryGenreMembership')));
  });

  test('below API 30: fills genres from the membership query', () async {
    mockPlatform(sdkInt: 28);
    final songs = await MediaStoreChannel().querySongs();

    expect(songs.map((s) => s.genre), ['Jazz', 'Jazz']);
    expect(calls, contains('queryGenreMembership'));
  });

  test('genreBySongId keeps the first genre per song', () {
    expect(
      genreBySongId({
        'Jazz': [1, 2],
        'Blues': [2, 3],
      }),
      {1: 'Jazz', 2: 'Jazz', 3: 'Blues'},
    );
  });

  test('loadArtwork passes its arguments through', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return Uint8List.fromList([1, 2, 3]);
        });

    final bytes = await MediaStoreChannel().loadArtwork(
      songId: 5,
      albumId: 9,
      sizePx: 256,
    );

    expect(bytes, [1, 2, 3]);
    expect(received!.arguments, {'songId': 5, 'albumId': 9, 'sizePx': 256});
  });

  test('column decoding matches the per-song parser', () {
    final rows = <Map<String, Object?>>[
      {
        'id': 7,
        'title': 'Señorita Café',
        'artist': 'Beyoncé Sinewave',
        'album': 'Ünïcode Dreams',
        'albumArtist': null,
        'albumId': 40,
        'artistId': 3,
        'genre': 'Pop',
        'track': 2005,
        'year': 2021,
        'durationMs': 180000,
        'sizeBytes': 5000000,
        'mimeType': 'audio/mpeg',
        'path': '/storage/emulated/0/Music/Uni/07.mp3',
        'dateAddedSec': 1700000000,
        'dateModifiedSec': 1700000100,
      },
      {
        'id': 8,
        'title': null, // falls back to the file name
        'artist': '<unknown>',
        'album': 'Ünïcode Dreams',
        'albumId': 40,
        'track': 0,
        'year': 0,
        'durationMs': 90000,
        'sizeBytes': 100,
        'mimeType': 'audio/mpeg',
        'path': '/storage/emulated/0/Music/Uni/08 Track.flac',
        'dateAddedSec': 1700000000,
        'dateModifiedSec': 1700000000,
      },
      {'id': null, 'path': '/m/broken.mp3'},
      {'id': 9, 'path': 'no-folder.mp3', 'title': 'X'},
    ];
    // Through the real codec, as the platform would send it.
    const codec = StandardMethodCodec();
    final decoded = codec.decodeEnvelope(
      codec.encodeSuccessEnvelope(columnsReply(rows)),
    ) as Map<Object?, Object?>;

    final fromColumns = MediaStoreSong.fromColumns(decoded);
    final fromMaps = [for (final row in rows) ?MediaStoreSong.tryParse(row)];
    String describe(MediaStoreSong s) => [
      s.id,
      s.title,
      s.artist,
      s.album,
      s.albumArtist,
      s.albumId,
      s.artistId,
      s.genre,
      s.trackNumber,
      s.discNumber,
      s.year,
      s.duration,
      s.sizeBytes,
      s.mimeType,
      s.path,
      s.folderPath,
      s.folderName,
      s.dateAdded,
      s.dateModified,
    ].join('|');
    expect(fromColumns.map(describe), fromMaps.map(describe));
    expect(fromColumns, hasLength(3));
    expect(fromColumns[1].title, '08 Track');
    expect(fromColumns[0].discNumber, 2);
  });

  test(
    'startup waits for the channel instead of failing (headless start)',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test/late');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var calls = 0;
      // No handler yet: like audio_service's background engine before
      // MainActivity has attached.
      final reply = MediaStoreChannel(channel: channel)
          .sdkIntWhenReady(interval: const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return 34;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(await reply, 34);
      expect(calls, 1);

      // Other failures are not swallowed.
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'boom'),
      );
      await expectLater(
        MediaStoreChannel(channel: channel).sdkIntWhenReady(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
