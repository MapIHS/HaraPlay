import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/now_playing_screen.dart';
import 'package:haraplay/features/player/presentation/queue_sheet.dart';
import 'package:haraplay/features/player/presentation/song_actions_sheet.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  Future<AppDatabase> library() async {
    final db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(
        1,
        title: 'Alpha',
        artist: 'Kai Tone',
        album: 'Night',
        albumId: 10,
        track: 1,
        path: '/m/a.flac',
      ),
      mediaSong(
        2,
        title: 'Beta',
        artist: 'Kai Tone',
        album: 'Night',
        albumId: 10,
        track: 2,
        path: '/m/b.mp3',
      ),
      mediaSong(
        3,
        title: 'Gamma',
        artist: 'Ana Sine',
        album: 'Day',
        albumId: 20,
        path: '/m/c.ogg',
      ),
    ]);
    return db;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<FakePlayer> openLibrary(WidgetTester tester) async {
    final player = FakePlayer();
    await pumpHaraApp(tester, database: await library(), player: player);
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(HaraBottomNav),
        matching: find.text('Library'),
      ),
    );
    return player;
  }

  QueueSong song(int id) => QueueSong(
    id: id,
    title: 'Song $id',
    artist: 'Kai Tone',
    path: '/m/$id.mp3',
    duration: const Duration(minutes: 3),
    version: 1,
  );

  group('song actions', () {
    testWidgets('play next and add to queue edit the queue', (tester) async {
      final player = await openLibrary(tester);
      await player.playSongs([song(7), song(8)], source: PlaySource.songs);
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Gamma'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Play next'));
      expect(player.queueIds, [7, 3, 8]);
      expect(find.text('Playing next: Gamma'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.widgetWithText(InkWell, 'Alpha').first,
          matching: find.byTooltip('More options'),
        ),
      );
      await tapAndSettle(tester, find.text('Add to queue'));
      expect(player.queueIds, [7, 3, 8, 1]);
    });

    testWidgets('the sheet covers the docked player and navigation', (
      tester,
    ) async {
      final player = await openLibrary(tester);
      await player.playSongs([song(7)], source: PlaySource.songs);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Gamma'));
      await tester.pumpAndSettle();

      // Tapping where the mini player sits hits the sheet's barrier, not
      // the player: the sheet is on the root navigator, above the shell.
      await tester.tapAt(tester.getCenter(find.byType(MiniPlayer)));
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsNothing); // sheet dismissed
      expect(find.byType(NowPlayingScreen), findsNothing);
    });

    testWidgets('adding to an empty queue starts playback', (tester) async {
      final player = await openLibrary(tester);
      await tester.longPress(find.text('Beta'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Add to queue'));
      expect(player.queueIds, [2]);
      expect(player.played.single.$3, PlaySource.queue);
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('go to album and song info', (tester) async {
      await openLibrary(tester);
      await tester.longPress(find.text('Beta'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Go to album'));
      expect(find.text('ALBUM'), findsOneWidget);
      expect(find.text('Night'), findsWidgets);

      await tester.longPress(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Song info'));
      expect(find.text('Song info'), findsOneWidget);
      expect(find.text('FLAC'), findsOneWidget);
      expect(find.text('/m/a.flac'), findsOneWidget);
      expect(find.text('Kai Tone'), findsWidgets);
    });

    test('format and size labels', () {
      expect(formatLabel('/m/x/Song.Name.flac', 'audio/flac'), 'FLAC');
      expect(formatLabel('/m/noext', 'audio/mpeg'), 'audio/mpeg');
      expect(formatFileSize(5452595), '5.2 MB');
      expect(formatFileSize(870 * 1024), '870 KB');
    });
  });

  group('queue sheet', () {
    Future<FakePlayer> openQueue(WidgetTester tester) async {
      final player = FakePlayer();
      await pumpHaraApp(tester, player: player);
      await player.playSongs(
        [song(1), song(2), song(3), song(4)],
        startIndex: 1,
        source: PlaySource.album,
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byType(MiniPlayer));
      await tapAndSettle(tester, find.text('Up next · 2'));
      expect(find.byType(QueueSheet), findsOneWidget);
      return player;
    }

    Finder row(String title) => find.descendant(
      of: find.byType(QueueSheet),
      matching: find.text(title),
    );

    testWidgets('shows the count and plays a tapped song', (tester) async {
      final player = await openQueue(tester);
      expect(find.bySemanticsLabel('Up next, 2 songs'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Song 2, Kai Tone, now playing'),
        findsOneWidget,
      );

      await tapAndSettle(tester, row('Song 4'));
      expect(player.currentIndex, 3);
    });

    testWidgets('swipe removes, but not the current song', (tester) async {
      final player = await openQueue(tester);
      await tester.drag(row('Song 3'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(player.queueIds, [1, 2, 4]);
      expect(row('Song 3'), findsNothing);

      await tester.drag(row('Song 2'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(player.queueIds, [1, 2, 4]);
    });

    testWidgets('drag the grip to reorder', (tester) async {
      final player = await openQueue(tester);
      final handle = find.descendant(
        of: find.byType(QueueSheet),
        matching: find.byType(ReorderableDragStartListener),
      );
      // Drag Song 4's grip (the last one) up two rows.
      final gesture = await tester.startGesture(tester.getCenter(handle.last));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, -QueueSheet.rowHeight * 2));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      // Two rows up: Song 4 lands above the current song, which keeps
      // playing at its new position.
      expect(player.queueIds, [1, 4, 2, 3]);
      expect(player.currentIndex, 2);
      expect(player.currentStatus.song?.id, 2);
    });

    testWidgets('clear removes everything after the current song', (
      tester,
    ) async {
      final player = await openQueue(tester);
      await tapAndSettle(tester, find.text('Clear'));
      expect(player.queueIds, [1, 2]);
      expect(find.bySemanticsLabel('Up next, 0 songs'), findsOneWidget);
    });
  });
}
