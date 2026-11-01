import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/library/presentation/album_detail_screen.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/now_playing_screen.dart';
import 'package:haraplay/features/search/presentation/search_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  // A phone-sized screen (360 × 800 dp).
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
  });

  Future<AppDatabase> library({int extraDrives = 0}) async {
    db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(
        1,
        title: 'Night Drive',
        artist: 'Mono Lisa',
        album: 'Midnight',
        albumId: 7,
      ),
      mediaSong(
        2,
        title: 'Drive Home',
        artist: 'Kai Tone',
        album: 'Roads',
        albumId: 8,
      ),
      mediaSong(
        3,
        title: 'Señorita Café',
        artist: 'Beyoncé Sinewave',
        album: 'Ünïcode',
        albumId: 9,
      ),
      for (var i = 0; i < extraDrives; i++)
        mediaSong(
          100 + i,
          title: 'Drive $i',
          artist: 'Bulk',
          album: 'Bulk',
          albumId: 50,
          path: '/m/b$i.mp3',
        ),
    ]);
    return db;
  }

  /// Lets database work started by the UI finish (drift needs real async).
  Future<void> settleDb(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settleDb(tester);
  }

  /// The page's vertical list (Home has horizontal rows inside it).
  final mainList = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;

  Finder navTab(String label) => find.descendant(
    of: find.byType(HaraBottomNav),
    matching: find.text(label),
  );

  Future<void> listen(int songId, int minute, {int seconds = 120}) =>
      db.playEventsDao.insertEvent(
        PlayEventsCompanion.insert(
          songId: Value(songId),
          songPath: '/m/$songId',
          title: 'Song $songId',
          startedAt: minute * 60000,
          listenedMs: seconds * 1000,
          durationMs: 180000,
          completed: true,
          source: PlaySource.songs,
        ),
      );

  group('Home', () {
    testWidgets('no music: a welcome with a way to the Library', (
      tester,
    ) async {
      await pumpHaraApp(tester);
      expect(find.text('Welcome to HaraPlay'), findsOneWidget);
      await tapAndSettle(tester, find.text('Open Library'));
      expect(find.text('No music yet'), findsOneWidget);
    });

    testWidgets('a fresh library: chips, hints, recently added, shuffle all', (
      tester,
    ) async {
      final player = FakePlayer();
      await pumpHaraApp(tester, database: await library(), player: player);
      await settleDb(tester);

      expect(find.text('3'), findsNWidgets(2)); // 3 songs, 3 albums
      expect(find.text('Songs you listen to will show up here.'), findsOne);
      expect(find.textContaining('Your top songs appear'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Midnight'),
        200,
        scrollable: mainList,
      );
      expect(find.text('Roads'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Shuffle all'),
        -200,
        scrollable: mainList,
      );
      await tapAndSettle(tester, find.text('Shuffle all'));
      final (songs, _, source) = player.played.single;
      expect(songs, hasLength(3));
      expect(source, PlaySource.songs);
      expect(player.shuffleArgs.single, isTrue);
    });

    testWidgets('recently played and most played come from play events', (
      tester,
    ) async {
      final player = FakePlayer();
      await pumpHaraApp(tester, database: await library(), player: player);
      await listen(2, 1);
      await listen(2, 2);
      await listen(1, 3);
      await listen(3, 4, seconds: 3); // a skip
      await settleDb(tester);

      expect(find.text('2 plays · Kai Tone'), findsOneWidget);
      expect(find.text('1 play · Mono Lisa'), findsOneWidget);
      expect(find.textContaining('Beyoncé'), findsNothing);

      // Newest first: Night Drive, then Drive Home.
      await tapAndSettle(tester, find.text('Night Drive').first);
      final (songs, index, source) = player.played.single;
      expect([for (final s in songs) s.id], [1, 2]);
      expect(index, 0);
      expect(source, PlaySource.songs);
      expect(player.labels.single, 'Recently played');
    });

    testWidgets('a recently added album opens inside the Home tab', (
      tester,
    ) async {
      await pumpHaraApp(tester, database: await library());
      await settleDb(tester);
      // To the end, clear of the docked player and the bottom navigation.
      await tester.drag(mainList, const Offset(0, -1000));
      await settleDb(tester);
      await tapAndSettle(tester, find.text('Midnight'));

      expect(find.byType(AlbumDetailScreen), findsOneWidget);
      final nav = tester.widget<HaraBottomNav>(find.byType(HaraBottomNav));
      expect(nav.currentIndex, 0);
    });
  });

  group('Search', () {
    Future<FakePlayer> openSearch(WidgetTester tester, {int extra = 0}) async {
      final player = FakePlayer();
      await pumpHaraApp(
        tester,
        database: await library(extraDrives: extra),
        player: player,
      );
      await tapAndSettle(tester, navTab('Search'));
      return player;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(SearchScreen.debounce);
      await settleDb(tester);
    }

    testWidgets('grouped results; tapping a song plays the results', (
      tester,
    ) async {
      final player = await openSearch(tester);
      expect(find.text('Search your music'), findsOneWidget);

      await type(tester, 'drive');
      expect(find.text('SONGS · 2'), findsOneWidget);
      expect(find.text('ALBUMS · 0'), findsNothing);

      await tapAndSettle(tester, find.text('Drive Home'));
      final (songs, index, source) = player.played.single;
      expect([for (final s in songs) s.title], ['Drive Home', 'Night Drive']);
      expect(index, 0);
      expect(source, PlaySource.search);
      expect(player.labels.single, 'drive');

      // The query became a recent search.
      await tapAndSettle(tester, find.byTooltip('Clear search'));
      expect(find.text('RECENT SEARCHES'), findsOneWidget);
      await tapAndSettle(tester, find.text('drive'));
      expect(find.text('SONGS · 2'), findsOneWidget);
    });

    testWidgets('accents, albums and artists', (tester) async {
      await openSearch(tester);
      await type(tester, 'beyonce');
      expect(find.text('SONGS · 1'), findsOneWidget);
      expect(find.text('ALBUMS · 1'), findsOneWidget);
      expect(find.text('ARTISTS · 1'), findsOneWidget);

      await type(tester, 'unicode');
      expect(find.text('ALBUMS · 1'), findsOneWidget);
    });

    testWidgets('see all expands a long group', (tester) async {
      await openSearch(tester, extra: 8);
      await type(tester, 'drive');
      expect(find.text('SONGS · 10'), findsOneWidget);
      expect(find.text('Drive 7'), findsNothing);

      await tapAndSettle(tester, find.text('See all'));
      await tester.scrollUntilVisible(
        find.text('Drive 7'),
        200,
        scrollable: mainList,
      );
      expect(find.text('Drive 7'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Show less'),
        -200,
        scrollable: mainList,
      );
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('no matches', (tester) async {
      await openSearch(tester);
      await type(tester, 'zzz');
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('an album opens inside the Search tab; back returns', (
      tester,
    ) async {
      await openSearch(tester);
      await type(tester, 'midnight');
      await tapAndSettle(tester, find.text('Midnight').last);

      expect(find.byType(AlbumDetailScreen), findsOneWidget);
      final nav = tester.widget<HaraBottomNav>(find.byType(HaraBottomNav));
      expect(nav.currentIndex, 2);

      await tester.pageBack();
      await settleDb(tester);
      expect(find.text('ALBUMS · 1'), findsOneWidget);
    });

    testWidgets('closing a sheet in Now Playing does not reopen the '
        'keyboard for the search field behind it', (tester) async {
      final player = await openSearch(tester);
      await type(tester, 'drive');
      expect(tester.testTextInput.isVisible, isTrue);

      await tapAndSettle(tester, find.text('Drive Home'));
      await tapAndSettle(tester, find.byType(MiniPlayer));
      expect(tester.testTextInput.isVisible, isFalse);
      await tapAndSettle(tester, find.textContaining('Up next'));
      await tester.binding.handlePopRoute();
      await settleDb(tester);

      expect(find.byType(NowPlayingScreen), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(player.played, isNotEmpty);
    });

    testWidgets('switching tabs drops the search focus, so closing '
        'Settings does not bring the keyboard back over Home', (tester) async {
      await openSearch(tester);
      await type(tester, 'drive');
      expect(tester.testTextInput.isVisible, isTrue);

      await tapAndSettle(tester, navTab('Home'));
      expect(tester.testTextInput.isVisible, isFalse);
      await tapAndSettle(tester, find.byTooltip('Settings'));
      await tester.binding.handlePopRoute();
      await settleDb(tester);

      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('recent searches: newest first, remove and clear', (
      tester,
    ) async {
      await openSearch(tester);
      for (final q in ['one', 'two', 'One']) {
        await tester.enterText(find.byType(TextField), q);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settleDb(tester);
      }
      await tapAndSettle(tester, find.byTooltip('Clear search'));
      final texts = [
        for (final e
            in find
                .descendant(
                  of: find.byType(InkWell),
                  matching: find.byType(Text),
                )
                .evaluate())
          (e.widget as Text).data,
      ];
      expect(texts.where((t) => t == 'One' || t == 'two'), ['One', 'two']);
      expect(find.text('one'), findsNothing);

      await tapAndSettle(
        tester,
        find.byTooltip('Remove "two" from recent searches'),
      );
      expect(find.text('two'), findsNothing);
      await tapAndSettle(tester, find.text('Clear'));
      expect(find.text('Search your music'), findsOneWidget);
    });
  });
}
