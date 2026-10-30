import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/platform/media_store_channel.dart';

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
            'querySongs' => [
              {
                'id': 1,
                'path': '/m/a.mp3',
                'genre': sdkInt >= 30 ? 'Rock' : null,
              },
              {'id': 2, 'path': '/m/b.mp3'},
              {'id': null, 'path': '/m/broken.mp3'},
            ],
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
}
