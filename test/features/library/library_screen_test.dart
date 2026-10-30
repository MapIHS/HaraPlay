import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/widgets/song_tile.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  Future<AppDatabase> library() async {
    final db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(
        1,
        title: 'Opener',
        artist: 'Mono Lisa',
        album: 'Night Drive',
        albumId: 10,
        year: 2019,
        track: 1,
        path: '/m/nd/1.ogg',
      ),
      mediaSong(
        2,
        title: 'Closer',
        artist: 'Mono Lisa',
        album: 'Night Drive',
        albumId: 10,
        track: 2,
        path: '/m/nd/2.ogg',
      ),
      mediaSong(
        3,
        title: 'Disc Two Opener',
        artist: 'Kai Tone',
        album: 'Double Feature',
        albumId: 20,
        track: 2001,
        genre: 'Jazz',
        path: '/m/df/a.m4a',
      ),
      mediaSong(
        4,
        title: 'Disc One Closer',
        artist: 'Ana Sine',
        album: 'Double Feature',
        albumId: 20,
        track: 1009,
        genre: 'Jazz',
        path: '/m/df/b.m4a',
      ),
      mediaSong(5, title: 'Field Recording', albumId: 30, path: '/m/u/x.wav'),
    ]);
    return db;
  }

  Future<void> openLibrary(WidgetTester tester, {AppDatabase? db}) async {
    await pumpHaraApp(tester, database: db ?? await library());
    await tester.tap(
      find.descendant(
        of: find.byType(HaraBottomNav),
        matching: find.text('Library'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('songs tab lists songs with unknown placeholders', (
    tester,
  ) async {
    await openLibrary(tester);

    expect(find.text('5 songs · 15 min'), findsOneWidget);
    expect(find.text('Field Recording'), findsOneWidget);
    expect(find.text('Unknown artist · Unknown album'), findsOneWidget);
    expect(find.text('Mono Lisa · Night Drive'), findsNWidgets(2));
  });

  testWidgets('sorting songs by artist puts unknown artists last', (
    tester,
  ) async {
    await openLibrary(tester);
    await tapAndSettle(tester, find.text('Title'));
    await tapAndSettle(tester, find.text('Artist'));

    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where(
          (t) => const [
            'Opener',
            'Closer',
            'Disc Two Opener',
            'Disc One Closer',
            'Field Recording',
          ].contains(t),
        )
        .toList();
    expect(titles.first, 'Disc One Closer'); // Ana Sine
    expect(titles.last, 'Field Recording'); // no artist
    // The choice is shown on the sort button.
    expect(find.text('Artist'), findsOneWidget);
  });

  testWidgets('album detail: disc headers, chips, artist link', (tester) async {
    await openLibrary(tester);
    await tapAndSettle(tester, find.text('Albums'));
    expect(find.text('3 albums'), findsOneWidget);
    expect(find.text('Various artists'), findsOneWidget);

    await tapAndSettle(tester, find.text('Double Feature'));
    expect(find.text('by Various artists'), findsOneWidget);
    expect(find.text('TRACKS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DISC 2'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('DISC 1'), findsOneWidget);
    expect(find.text('Disc Two Opener'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Night Drive'));
    expect(find.text('2019'), findsOneWidget);
    await tapAndSettle(tester, find.text('by Mono Lisa'));
    expect(find.text('ARTIST'), findsOneWidget);
    expect(find.text('Mono Lisa'), findsOneWidget);
  });

  testWidgets('unknown artist has its own page', (tester) async {
    await openLibrary(tester);
    await tapAndSettle(tester, find.text('Artists'));
    await tapAndSettle(tester, find.text('Unknown artist'));
    expect(find.text('ARTIST'), findsOneWidget);
    expect(find.text('Field Recording'), findsOneWidget);
  });

  testWidgets('folders and genres open their songs', (tester) async {
    await openLibrary(tester);
    await tapAndSettle(tester, find.text('Folders'));
    await tapAndSettle(tester, find.text('df'));
    expect(find.text('FOLDER'), findsOneWidget);
    expect(find.text('/m/df'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Genres'));
    await tapAndSettle(tester, find.text('Jazz'));
    expect(find.text('GENRE'), findsOneWidget);
    expect(find.text('Disc Two Opener'), findsOneWidget);
  });

  testWidgets('a library without genre tags explains the empty tab', (
    tester,
  ) async {
    final db = createTestDatabase();
    await db.libraryDao.applyScan([mediaSong(1)]);
    await openLibrary(tester, db: db);
    await tapAndSettle(tester, find.text('Genres'));
    expect(find.text('No genres'), findsOneWidget);
  });

  testWidgets('album Play queues the album from the first track', (
    tester,
  ) async {
    final player = FakePlayer();
    await pumpHaraApp(tester, database: await library(), player: player);
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(HaraBottomNav),
        matching: find.text('Library'),
      ),
    );
    await tapAndSettle(tester, find.text('Albums'));
    await tapAndSettle(tester, find.text('Night Drive'));
    await tapAndSettle(tester, find.text('Play'));

    final (songs, index, source) = player.played.single;
    expect(songs.map((s) => s.title), ['Opener', 'Closer']);
    expect(index, 0);
    expect(source, PlaySource.album);

    expect(player.labels.single, 'Night Drive');
    expect(player.shuffleArgs.single, isNull); // keeps the shuffle setting

    await tapAndSettle(tester, find.text('Shuffle'));
    final (shuffled, _, shuffleSource) = player.played.last;
    expect(shuffled.map((s) => s.title), ['Opener', 'Closer']);
    expect(shuffleSource, PlaySource.album);
    expect(player.shuffleArgs.last, isTrue); // turns shuffle mode on
  });

  testWidgets('tapping a song plays the list from it; mini player appears', (
    tester,
  ) async {
    final player = FakePlayer();
    await pumpHaraApp(tester, database: await library(), player: player);
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(HaraBottomNav),
        matching: find.text('Library'),
      ),
    );
    expect(find.byType(MiniPlayer), findsNothing);

    await tapAndSettle(tester, find.text('Disc Two Opener'));

    final (songs, index, source) = player.played.single;
    expect(source, PlaySource.songs);
    expect(songs, hasLength(5)); // the whole visible list, in its order
    expect(songs[index].title, 'Disc Two Opener');

    // Mini player shows the song and drives the player.
    expect(
      find.bySemanticsLabel('Now playing: Disc Two Opener by Kai Tone'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.byTooltip('Pause'));
    expect(player.toggles, 1);
    expect(find.byTooltip('Play'), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('Next'));
    expect(player.nexts, 1);

    // The playing row is highlighted, and only that one.
    final tiles = tester.widgetList<SongTile>(find.byType(SongTile));
    expect(tiles.where((t) => t.selected).map((t) => t.title), [
      'Disc Two Opener',
    ]);
  });
}
