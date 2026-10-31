import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/icons/hara_icons.dart';
import 'package:haraplay/core/widgets/heart_mark.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/now_playing_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  // A phone-sized screen (360 × 800 dp), so playlist rows are on screen.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
  });

  Future<AppDatabase> library() async {
    db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(1, title: 'Alpha', artist: 'Kai Tone', albumId: 10),
      mediaSong(2, title: 'Beta', artist: 'Kai Tone', albumId: 10),
      mediaSong(3, title: 'Gamma', artist: 'Ana Sine', albumId: 20),
    ]);
    return db;
  }

  /// Lets database work started by the UI finish: drift runs on real
  /// async, which the widget test's fake clock does not advance.
  Future<void> settleDb(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeText(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settleDb(tester);
  }

  Finder navTab(String label) => find.descendant(
    of: find.byType(HaraBottomNav),
    matching: find.text(label),
  );

  Future<FakePlayer> open(WidgetTester tester, String tab) async {
    final player = FakePlayer();
    await pumpHaraApp(tester, database: await library(), player: player);
    await tapAndSettle(tester, navTab(tab));
    return player;
  }

  Future<void> actionsFor(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title).first);
    await settleDb(tester);
  }

  /// Stream queries need real async; the widget test zone is fake.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() read) async =>
      (await tester.runAsync(read)) as T;

  Future<List<String>> entryTitles(WidgetTester tester, int playlistId) => real(
    tester,
    () async => [
      for (final e in await db.playlistsDao.watchEntries(playlistId).first)
        e.song.title,
    ],
  );

  testWidgets('like from the actions sheet shows a heart in the tile and '
      'the song in Liked songs', (tester) async {
    await open(tester, 'Library');
    expect(find.byType(HeartMark), findsNothing);

    await actionsFor(tester, 'Beta');
    await tapAndSettle(tester, find.text('Add to Liked songs'));
    expect(find.text('Added to Liked songs'), findsOneWidget);
    expect(find.byType(HeartMark), findsOneWidget);

    // The sheet now offers the opposite.
    await actionsFor(tester, 'Beta');
    expect(find.text('Remove from Liked songs'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settleDb(tester);

    await tapAndSettle(tester, navTab('Playlists'));
    expect(find.text('1 song'), findsOneWidget);
    await tapAndSettle(tester, find.text('Liked songs'));
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    // Unlike from the list itself.
    await actionsFor(tester, 'Beta');
    await tapAndSettle(tester, find.text('Remove from Liked songs'));
    expect(find.text('No liked songs yet'), findsOneWidget);
  });

  testWidgets('Liked songs plays with the favorites source', (tester) async {
    final player = await open(tester, 'Playlists');
    await db.favoritesDao.setLiked(3, liked: true, at: DateTime(2026));
    await db.favoritesDao.setLiked(1, liked: true, at: DateTime(2027));
    await settleDb(tester);
    await tapAndSettle(tester, find.text('Liked songs'));

    await tapAndSettle(tester, find.text('Play'));
    final (songs, index, source) = player.played.single;
    expect([for (final s in songs) s.title], ['Alpha', 'Gamma']);
    expect(index, 0);
    expect(source, PlaySource.favorites);
  });

  testWidgets('the heart in Now Playing toggles the like', (tester) async {
    final player = FakePlayer();
    await pumpHaraApp(tester, database: await library(), player: player);
    await player.playSongs([
      QueueSong.fromRow(
        (await real(
          tester,
          () => db.select(db.songs).get(),
        )).firstWhere((s) => s.id == 2),
      ),
    ], source: PlaySource.songs);
    await settleDb(tester);
    await tapAndSettle(tester, find.byType(MiniPlayer));
    expect(find.byType(NowPlayingScreen), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Add to Liked songs'));
    expect(await real(tester, () => db.favoritesDao.watchLikedIds().first), {
      2,
    });
    expect(find.byTooltip('Remove from Liked songs'), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Remove from Liked songs'));
    expect(
      await real(tester, () => db.favoritesDao.watchLikedIds().first),
      isEmpty,
    );
  });

  testWidgets('add to a new playlist from the actions sheet, then to an '
      'existing one', (tester) async {
    await open(tester, 'Library');

    await actionsFor(tester, 'Gamma');
    await tapAndSettle(tester, find.text('Add to playlist'));
    await tapAndSettle(tester, find.text('New playlist'));
    // Create stays disabled until there is a name.
    await typeText(tester, '   ');
    await tapAndSettle(tester, find.text('Create'));
    expect(find.text('Create'), findsOneWidget);
    await typeText(tester, '  Road   trip ');
    await tapAndSettle(tester, find.text('Create'));
    expect(find.text('Added to Road trip'), findsOneWidget);

    final playlist = (await real(
      tester,
      () => db.playlistsDao.watchPlaylists().first,
    )).single;
    expect(playlist.name, 'Road trip');
    expect(await entryTitles(tester, playlist.id), ['Gamma']);

    // The sheet marks a playlist that already has the song.
    await actionsFor(tester, 'Gamma');
    await tapAndSettle(tester, find.text('Add to playlist'));
    expect(find.textContaining('Already has this song'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settleDb(tester);

    await actionsFor(tester, 'Alpha');
    await tapAndSettle(tester, find.text('Add to playlist'));
    await tapAndSettle(tester, find.text('Road trip'));
    expect(await entryTitles(tester, playlist.id), ['Gamma', 'Alpha']);
  });

  group('playlist screen', () {
    Future<int> openPlaylist(WidgetTester tester, List<int> songIds) async {
      final player = FakePlayer();
      await pumpHaraApp(tester, database: await library(), player: player);
      final id = await db.playlistsDao.create('Mix', at: DateTime(2026));
      await db.playlistsDao.addSongs(id, songIds, at: DateTime(2026));
      await tapAndSettle(tester, navTab('Playlists'));
      expect(find.text('3 songs · 9 min'), findsOneWidget);
      await tapAndSettle(tester, find.text('Mix'));
      return id;
    }

    testWidgets('create from the tab opens the empty playlist', (tester) async {
      await open(tester, 'Playlists');
      expect(find.textContaining('No playlists yet'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('New playlist'));
      await typeText(tester, 'Focus');
      await tapAndSettle(tester, find.text('Create'));

      expect(find.text('PLAYLIST'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.textContaining('This playlist is empty'), findsOneWidget);
    });

    testWidgets('add songs picker appends in the order ticked', (tester) async {
      await open(tester, 'Playlists');
      final id = await db.playlistsDao.create('Empty', at: DateTime(2026));
      await settleDb(tester);
      await tapAndSettle(tester, find.text('Empty').first);
      await tapAndSettle(tester, find.text('Add songs'));

      await typeText(tester, 'kai');
      await settleDb(tester);
      expect(find.text('Gamma'), findsNothing);
      await tapAndSettle(tester, find.text('Beta'));
      await typeText(tester, '');
      await settleDb(tester);
      await tapAndSettle(tester, find.text('Gamma'));
      await tapAndSettle(tester, find.text('Add 2 songs'));

      expect(await entryTitles(tester, id), ['Beta', 'Gamma']);
      expect(find.text('Added 2 songs to Empty'), findsOneWidget);
    });

    testWidgets('play starts the playlist with its name', (tester) async {
      final player = FakePlayer();
      await pumpHaraApp(tester, database: await library(), player: player);
      final id = await db.playlistsDao.create('Mix', at: DateTime(2026));
      await db.playlistsDao.addSongs(id, [3, 1], at: DateTime(2026));
      await tapAndSettle(tester, navTab('Playlists'));
      await tapAndSettle(tester, find.text('Mix'));

      await tapAndSettle(tester, find.text('Alpha'));
      final (songs, index, source) = player.played.single;
      expect([for (final s in songs) s.id], [3, 1]);
      expect(index, 1);
      expect(source, PlaySource.playlist);
      expect(player.labels.single, 'Mix');
    });

    testWidgets('swipe removes an entry, Undo puts it back', (tester) async {
      final id = await openPlaylist(tester, [1, 2, 3]);

      await tester.drag(find.text('Beta'), const Offset(-500, 0));
      await settleDb(tester);
      expect(find.text('Beta'), findsNothing);
      expect(await entryTitles(tester, id), ['Alpha', 'Gamma']);

      await tapAndSettle(tester, find.text('Undo'));
      expect(await entryTitles(tester, id), ['Alpha', 'Beta', 'Gamma']);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('remove from the actions sheet', (tester) async {
      final id = await openPlaylist(tester, [1, 2, 3]);
      await actionsFor(tester, 'Gamma');
      await tapAndSettle(tester, find.text('Remove from this playlist'));
      expect(await entryTitles(tester, id), ['Alpha', 'Beta']);
    });

    testWidgets('drag the grip to reorder', (tester) async {
      final id = await openPlaylist(tester, [1, 2, 3]);

      final grip = find.byIcon(HaraIcons.gripVertical);
      final gesture = await tester.startGesture(tester.getCenter(grip.first));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 16));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleDb(tester);

      expect(await entryTitles(tester, id), ['Beta', 'Gamma', 'Alpha']);
    });

    testWidgets('holding the grip before dragging still reorders, without '
        'opening the song actions', (tester) async {
      final id = await openPlaylist(tester, [1, 2, 3]);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(HaraIcons.gripVertical).first),
      );
      // Longer than a long-press.
      await tester.pump(const Duration(milliseconds: 800));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 16));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleDb(tester);

      expect(find.text('Play next'), findsNothing);
      expect(await entryTitles(tester, id), ['Beta', 'Gamma', 'Alpha']);
    });

    testWidgets('rename and delete from the options menu', (tester) async {
      await openPlaylist(tester, [1, 2, 3]);

      await tapAndSettle(tester, find.byTooltip('Playlist options'));
      await tapAndSettle(tester, find.text('Rename'));
      await typeText(tester, 'Evening');
      await tapAndSettle(tester, find.text('Save'));
      expect(find.text('Evening'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Playlist options'));
      await tapAndSettle(tester, find.text('Delete playlist'));
      expect(find.textContaining('The songs stay on your phone'), findsOne);
      await tapAndSettle(tester, find.text('Delete'));

      // Back on the tab, which is empty again.
      expect(find.textContaining('No playlists yet'), findsOneWidget);
      expect(
        await real(tester, () => db.playlistsDao.watchPlaylists().first),
        isEmpty,
      );
    });
  });
}
