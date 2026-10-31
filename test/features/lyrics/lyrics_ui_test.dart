import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/lyrics/presentation/lyrics_view.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  QueueSong song(int id) => QueueSong(
    id: id,
    title: 'Song $id',
    artist: 'Kai Tone',
    path: '/m/$id.mp3',
    duration: const Duration(minutes: 3),
    version: 1,
  );

  final synced = [
    '[ar:Kai Tone]',
    for (var i = 0; i < 40; i++)
      '[${((i * 4) ~/ 60).toString().padLeft(2, '0')}:'
          '${((i * 4) % 60).toString().padLeft(2, '0')}.00]Line number $i',
  ].join('\n');

  Future<FakePlayer> openLyrics(
    WidgetTester tester, {
    Map<String, String> lyrics = const {},
  }) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2280)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player, lyrics: FakeLyricsLoader(lyrics));
    await player.playSongs([song(1), song(2)], source: PlaySource.songs);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lyrics'));
    await tester.pumpAndSettle();
    return player;
  }

  /// Whether [text] is drawn with the current-line marker fill.
  bool highlighted(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.background != null;

  bool onScreen(WidgetTester tester, String text) {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return false;
    final box = tester.getRect(finder);
    final panel = tester.getRect(find.byType(LyricsPanel));
    return panel.overlaps(box);
  }

  testWidgets('synced lyrics follow the song; tapping a line seeks', (
    tester,
  ) async {
    final player = await openLyrics(tester, lyrics: {'/m/1.mp3': synced});
    expect(find.byType(LyricsPanel), findsOneWidget);
    // Line 0 starts at 0:00, so it is current right away.
    expect(highlighted(tester, 'Line number 0'), isTrue);

    player.emitPosition(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(highlighted(tester, 'Line number 2'), isTrue);
    expect(highlighted(tester, 'Line number 1'), isFalse);

    // Far down the song: the panel scrolls the line into view.
    expect(onScreen(tester, 'Line number 30'), isFalse);
    player.emitPosition(const Duration(seconds: 121));
    await tester.pumpAndSettle();
    expect(highlighted(tester, 'Line number 30'), isTrue);
    expect(onScreen(tester, 'Line number 30'), isTrue);

    await tester.tap(find.text('Line number 31'));
    await tester.pumpAndSettle();
    expect(player.seeks.last, const Duration(seconds: 124));
  });

  testWidgets('auto-scroll waits while the user scrolls', (tester) async {
    final player = await openLyrics(tester, lyrics: {'/m/1.mp3': synced});
    // The user scrolls back to the top...
    await tester.fling(find.byType(LyricsPanel), const Offset(0, 2000), 2000);
    await tester.pump(const Duration(milliseconds: 500));
    // ...and the song moves on: the view stays where the user put it.
    player.emitPosition(const Duration(seconds: 141));
    await tester.pump(const Duration(seconds: 1));
    expect(onScreen(tester, 'Line number 35'), isFalse);
    // A few seconds later it follows the song again.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(onScreen(tester, 'Line number 35'), isTrue);
  });

  testWidgets('plain lyrics are text only', (tester) async {
    final player = await openLyrics(
      tester,
      lyrics: {'/m/1.mp3': 'First words\n\nSecond words'},
    );
    expect(find.text('Second words'), findsOneWidget);
    // The blank line is a verse break, not an instrumental mark.
    expect(find.text('♪'), findsNothing);
    await tester.tap(find.text('First words'));
    await tester.pumpAndSettle();
    expect(player.seeks, isEmpty);
    player.emitPosition(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(highlighted(tester, 'First words'), isFalse);
  });

  testWidgets('a song without lyrics says so; the next song gets its own', (
    tester,
  ) async {
    final player = await openLyrics(
      tester,
      lyrics: {'/m/2.mp3': '[00:01.00]Second song line'},
    );
    expect(find.text('No lyrics for this song'), findsOneWidget);
    await player.skipTo(1);
    await tester.pumpAndSettle();
    expect(find.text('Second song line'), findsOneWidget);

    // Hiding lyrics brings the artwork back.
    await tester.tap(find.byTooltip('Hide lyrics'));
    await tester.pumpAndSettle();
    expect(find.byType(LyricsPanel), findsNothing);
  });

  testWidgets('full-screen lyrics', (tester) async {
    await openLyrics(tester, lyrics: {'/m/1.mp3': synced});
    await tester.tap(find.byTooltip('Full-screen lyrics'));
    await tester.pumpAndSettle();
    expect(find.byType(LyricsScreen), findsOneWidget);
    expect(find.text('Song 1'), findsWidgets);
    expect(find.text('Line number 0'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LyricsScreen), findsNothing);
    expect(find.byType(LyricsPanel), findsOneWidget);
  });
}
