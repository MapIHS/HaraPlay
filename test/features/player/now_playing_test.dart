import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/now_playing_screen.dart';
import 'package:haraplay/features/player/presentation/seek_bar.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  const song = QueueSong(
    id: 1,
    title: 'Night Drive',
    artist: 'Mono Lisa',
    album: 'Midnight',
    path: '/m/1.mp3',
    duration: Duration(minutes: 3),
    version: 1,
  );

  Future<FakePlayer> pumpPlaying(WidgetTester tester) async {
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player);
    await player.playSongs(
      [song],
      source: PlaySource.album,
      sourceLabel: 'Midnight',
    );
    await tester.pumpAndSettle();
    return player;
  }

  Finder nowPlaying() => find.byType(NowPlayingScreen);

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the mini player expands into Now Playing and back', (
    tester,
  ) async {
    await pumpPlaying(tester);
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(nowPlaying(), findsNothing);

    await tapAndSettle(
      tester,
      find.bySemanticsLabel('Now playing: Night Drive by Mono Lisa'),
    );
    expect(nowPlaying(), findsOneWidget);
    expect(find.text('Album · Midnight'), findsOneWidget);
    expect(find.text('Mono Lisa'), findsWidgets);

    await tapAndSettle(tester, find.byTooltip('Close player'));
    expect(nowPlaying(), findsNothing);
    expect(find.byType(MiniPlayer), findsOneWidget);
  });

  testWidgets('Android back collapses Now Playing first', (tester) async {
    await pumpPlaying(tester);
    await tapAndSettle(tester, find.byType(MiniPlayer));
    expect(nowPlaying(), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(nowPlaying(), findsNothing);
    // Still in the app, on Home.
    expect(find.byType(HaraBottomNav), findsOneWidget);
  });

  testWidgets('dragging the mini player up opens Now Playing', (tester) async {
    await pumpPlaying(tester);
    await tester.fling(find.byType(MiniPlayer), const Offset(0, -300), 1500);
    await tester.pumpAndSettle();
    expect(nowPlaying(), findsOneWidget);

    // A small drag down that is not a fling springs back open.
    await tester.drag(find.text('PLAYING FROM'), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(nowPlaying(), findsOneWidget);
    await tester.fling(find.text('PLAYING FROM'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(nowPlaying(), findsNothing);
  });

  testWidgets('shuffle and repeat buttons drive the player', (tester) async {
    final player = await pumpPlaying(tester);
    await tapAndSettle(tester, find.byType(MiniPlayer));

    await tapAndSettle(tester, find.byTooltip('Shuffle off'));
    expect(player.currentStatus.shuffle, isTrue);
    expect(find.byTooltip('Shuffle on'), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Repeat off'));
    expect(player.currentStatus.repeat, RepeatSetting.all);
    await tapAndSettle(tester, find.byTooltip('Repeat all'));
    expect(player.currentStatus.repeat, RepeatSetting.one);
    await tapAndSettle(tester, find.byTooltip('Repeat one'));
    expect(player.currentStatus.repeat, RepeatSetting.off);
  });

  testWidgets('transport buttons and the seek slider', (tester) async {
    final player = await pumpPlaying(tester);
    await tapAndSettle(tester, find.byType(MiniPlayer));

    await tapAndSettle(
      tester,
      find.descendant(of: nowPlaying(), matching: find.byTooltip('Pause')),
    );
    expect(player.toggles, 1);
    await tapAndSettle(
      tester,
      find.descendant(of: nowPlaying(), matching: find.byTooltip('Next')),
    );
    await tapAndSettle(tester, find.byTooltip('Previous'));
    expect((player.nexts, player.previouses), (1, 1));

    player.emitPosition(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('-2:30'), findsOneWidget);

    // Tap the middle of the slider: seeks to about half way.
    await tapAndSettle(tester, find.byType(Slider));
    expect(player.seeks, hasLength(1));
    expect(player.seeks.single.inSeconds, inInclusiveRange(80, 100));
  });

  test('remaining time rounds up', () {
    const total = Duration(seconds: 45, milliseconds: 46);
    expect(
      remainingLabel(const Duration(seconds: 15, milliseconds: 300), total),
      '-0:30',
    );
    expect(remainingLabel(Duration.zero, const Duration(seconds: 45)), '-0:45');
    expect(remainingLabel(total, total), '-0:00');
  });

  test('playingFrom labels', () {
    PlaybackStatus status(PlaySource source, [String? label]) => PlaybackStatus(
      song: song,
      playing: true,
      buffering: false,
      duration: Duration.zero,
      source: source,
      sourceLabel: label,
    );
    expect(playingFrom(status(PlaySource.songs, 'x')), 'All songs');
    expect(playingFrom(status(PlaySource.genre, 'Jazz')), 'Genre · Jazz');
    expect(playingFrom(status(PlaySource.album)), 'Album');
  });
}
