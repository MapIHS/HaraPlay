import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/open_with/data/open_with.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/playback_speed.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

const _song = QueueSong(
  id: 1,
  title: 'Night Drive',
  artist: 'Mono Lisa',
  path: '/m/1.mp3',
  duration: Duration(minutes: 3),
  version: 1,
);

OpenedAudio _file({
  int? mediaId,
  String? path,
  String? displayName,
  int? size,
  String? title,
  Uri? uri,
}) => (
  uri: uri ?? Uri.parse('content://com.whatsapp.provider/audio/9'),
  mediaId: mediaId,
  path: path,
  displayName: displayName,
  size: size,
  title: title,
  artist: null,
  album: null,
  duration: const Duration(seconds: 12),
);

void main() {
  void phoneView(WidgetTester tester) {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
  }

  Future<FakePlayer> openNowPlaying(
    WidgetTester tester, {
    Map<String, Object>? prefs,
    QueueSong song = _song,
  }) async {
    phoneView(tester);
    final player = FakePlayer();
    await pumpHaraApp(
      tester,
      player: player,
      prefs: {...onboardedPrefs, ...?prefs},
    );
    await player.playSongs([song], source: PlaySource.album);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();
    return player;
  }

  test('speed labels', () {
    expect(formatSpeed(1), '1×');
    expect(formatSpeed(1.25), '1.25×');
    expect(formatSpeed(0.5), '0.5×');
    expect(formatSpeed(2.0000001), '2×');
  });

  testWidgets('speed is set from Now Playing, shown as a chip, and reset', (
    tester,
  ) async {
    final player = await openNowPlaying(tester);
    expect(find.text('1.5×'), findsNothing);

    await tester.tap(find.byTooltip('Song actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playback speed · 1×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×').last);
    await tester.pumpAndSettle();
    expect(player.currentStatus.speed, 1.5);

    // Close the sheet: the chip shows the speed and reopens the sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Playback speed')), findsOneWidget);
    await tester.tap(find.text('1.5×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1×'));
    await tester.pumpAndSettle();
    expect(player.currentStatus.speed, 1);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Playback speed')), findsNothing);
  });

  testWidgets('a saved speed comes back with the app', (tester) async {
    await openNowPlaying(tester, prefs: {'playback.speed': 1.25});
    await tester.tap(find.byTooltip('Song actions'));
    await tester.pumpAndSettle();
    expect(find.text('Playback speed · 1.25×'), findsOneWidget);
  });

  testWidgets('an opened file outside the library plays without library '
      'actions', (tester) async {
    final opened = QueueSong.external(
      id: -1,
      uri: Uri.parse('content://com.whatsapp.provider/audio/9'),
      title: 'Voice note',
    );
    await openNowPlaying(tester, song: opened);
    expect(find.text('A shared file'), findsOneWidget);
    expect(find.text('Voice note'), findsWidgets);
    expect(find.byTooltip('Like'), findsNothing);

    await tester.tap(find.byTooltip('Song actions'));
    await tester.pumpAndSettle();
    expect(find.text('Playback speed · 1×'), findsOneWidget);
    expect(find.text('Add to playlist'), findsNothing);
    expect(find.text('Song info'), findsNothing);
  });

  group('OpenWith', () {
    late AppDatabase db;
    late FakePlayer player;
    late OpenWith opener;

    setUp(() async {
      db = createTestDatabase();
      await db.libraryDao.applyScan([
        mediaSong(7, path: '/storage/emulated/0/Music/a.mp3', title: 'Alpha'),
      ]);
      player = FakePlayer();
      opener = OpenWith(player, DatabaseOpenWithLibrary(db));
    });
    tearDown(() => db.close());

    test('a library file plays as the library song', () async {
      final byId = await opener.songFor(_file(mediaId: 7));
      expect((byId.id, byId.isExternal), (7, false));
      final byPath = await opener.songFor(
        _file(path: '/storage/emulated/0/Music/a.mp3'),
      );
      expect(byPath.id, 7);
      // Another name for the same storage.
      final byAlias = await opener.songFor(_file(path: '/sdcard/Music/a.mp3'));
      expect(byAlias.id, 7);
      // A file manager's link without a path: file name and size.
      final byFile = await opener.songFor(
        _file(displayName: 'a.mp3', size: 4000000),
      );
      expect(byFile.id, 7);
      final otherSize = await opener.songFor(
        _file(displayName: 'a.mp3', size: 123),
      );
      expect(otherSize.isExternal, isTrue);
    });

    test(
      'other files play from their URI, named by tag or file name',
      () async {
        final tagged = await opener.songFor(_file(title: 'Hello'));
        final named = await opener.songFor(_file(displayName: 'PTT-2026.opus'));
        expect(tagged.isExternal, isTrue);
        expect(tagged.title, 'Hello');
        expect(named.title, 'PTT-2026');
        expect(named.uri.toString(), 'content://com.whatsapp.provider/audio/9');
        expect({tagged.id, named.id}, {-1, -2}, reason: 'each its own ID');

        await opener.open(_file(displayName: 'clip.mp3'));
        expect(player.opened.single.title, 'clip');
        expect(player.currentStatus.source, PlaySource.external);
      },
    );
  });
}
