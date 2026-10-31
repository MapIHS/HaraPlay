import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/now_playing_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

/// Walks every main screen and sheet. Layout overflows and other errors
/// fail the test, so this runs at large text sizes on a small phone, and
/// checks the accessibility guidelines at the default size.
void main() {
  late AppDatabase db;

  Future<AppDatabase> library() async {
    db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(
        1,
        title: 'A rather long song title that will not fit on one line',
        artist: 'An artist with a long name, featuring several guests',
        album: 'Midnight Sessions, Deluxe Edition (Remastered)',
        albumId: 7,
        genre: 'Synthwave',
        year: 2021,
        track: 1,
      ),
      mediaSong(
        2,
        title: 'Drive Home',
        artist: 'Kai Tone',
        album: 'Roads',
        albumId: 8,
        genre: 'Pop',
        track: 1,
      ),
      mediaSong(
        3,
        title: 'Señorita Café',
        artist: 'Beyoncé Sinewave',
        album: 'Roads',
        albumId: 8,
        track: 2,
      ),
    ]);
    final id = await db.playlistsDao.create(
      'A playlist with a name long enough to wrap',
      at: DateTime(2026),
    );
    await db.playlistsDao.addSongs(id, [1, 2, 3], at: DateTime(2026));
    await db.favoritesDao.setLiked(1, liked: true, at: DateTime(2026));
    for (var i = 0; i < 3; i++) {
      await db.playEventsDao.insertEvent(
        PlayEventsCompanion.insert(
          songId: const Value(1),
          songPath: '/m/1',
          title: 'x',
          startedAt: i * 60000,
          listenedMs: 120000,
          durationMs: 180000,
          completed: true,
          source: PlaySource.songs,
        ),
      );
    }
    return db;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // `.first` finders throw instead of finding nothing.
    bool missing() {
      try {
        return finder.evaluate().isEmpty;
      } on StateError {
        return true;
      }
    }

    // At large text sizes a target may not be built yet: scroll down to it.
    for (var i = 0; i < 10 && missing(); i++) {
      await tester.drag(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last, // the current page's list
        warnIfMissed: false, // its centre may sit under the mini player
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }
    // Library tab chips and long lists scroll; bring the target into view.
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await settle(tester);
  }

  Finder navTab(String label) => find.descendant(
    of: find.byType(HaraBottomNav),
    matching: find.text(label),
  );

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  /// Opens every screen and sheet once.
  Future<void> tour(WidgetTester tester, FakePlayer player) async {
    // Home.
    await settle(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await settle(tester);

    // Library tabs and the detail pages.
    await tap(tester, navTab('Library'));
    for (final tab in ['Albums', 'Artists', 'Folders', 'Genres', 'Songs']) {
      await tap(tester, find.text(tab).first);
    }
    await tap(tester, find.text('Albums').first);
    await tap(tester, find.text('Roads').first);
    await back(tester);
    await tap(tester, find.text('Artists').first);
    await tap(tester, find.text('Kai Tone').first);
    await back(tester);
    await tap(tester, find.text('Songs').first);

    // Song actions and song info.
    await tester.longPress(find.text('Drive Home').first);
    await settle(tester);
    await tap(tester, find.text('Song info'));
    await back(tester);

    // Search with results.
    await tap(tester, navTab('Search'));
    await tester.enterText(find.byType(TextField), 'roads');
    await tester.pump(const Duration(milliseconds: 200));
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    // Playlists, a playlist, Liked songs, add-to-playlist and add-songs.
    await tap(tester, navTab('Playlists'));
    await tap(tester, find.textContaining('A playlist with').first);
    await tap(tester, find.text('Add songs').first);
    await back(tester);
    await back(tester);
    await tap(tester, find.text('Liked songs').first);
    await back(tester);

    // Now Playing with the queue sheet and its actions.
    await player.playSongs(
      [
        for (final s
            in await tester.runAsync(() => db.select(db.songs).get()) ??
                <SongRow>[])
          QueueSong.fromRow(s),
      ],
      source: PlaySource.playlist,
      sourceLabel: 'A playlist with a name long enough to wrap',
    );
    await settle(tester);
    await tap(tester, find.byType(MiniPlayer));
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await tap(tester, find.textContaining('Up next'));
    await back(tester);
    await tap(tester, find.byTooltip('Song actions'));
    await back(tester);
    await tap(tester, find.byTooltip('Close player'));

    // Settings.
    await tap(tester, navTab('Home'));
    await tap(tester, find.byTooltip('Settings'));
    await back(tester);
  }

  for (final (width, height, scale) in [
    (360.0, 760.0, 1.0),
    (360.0, 760.0, 1.5),
    (320.0, 640.0, 2.0),
  ]) {
    testWidgets('every screen lays out at ${width.toInt()}×${height.toInt()} '
        'dp with text at ${scale}x', (tester) async {
      final view = tester.view
        ..physicalSize = Size(width * 3, height * 3)
        ..devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final player = FakePlayer();
      await pumpHaraApp(tester, database: await library(), player: player);
      await tour(tester, player);
    });
  }

  testWidgets('main screens meet the tap-target and label guidelines', (
    tester,
  ) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2280)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final handle = tester.ensureSemantics();
    final player = FakePlayer();
    await pumpHaraApp(tester, database: await library(), player: player);
    await player.playSongs([
      for (final s
          in await tester.runAsync(() => db.select(db.songs).get()) ??
              <SongRow>[])
        QueueSong.fromRow(s),
    ], source: PlaySource.songs);
    await settle(tester);

    Future<void> check(String where) async {
      await expectLater(
        tester,
        meetsGuideline(androidTapTargetGuideline),
        reason: where,
      );
      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
        reason: where,
      );
    }

    await check('Home');
    for (final tab in ['Library', 'Search', 'Playlists']) {
      await tap(tester, navTab(tab));
      await check(tab);
    }
    await tap(tester, find.byType(MiniPlayer));
    await check('Now Playing');
    handle.dispose();
  });
}
