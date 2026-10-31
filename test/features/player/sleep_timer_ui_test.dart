import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/domain/sleep_timer_state.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/sleep_timer_sheet.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  const song = QueueSong(
    id: 1,
    title: 'Midnight Drive',
    artist: 'Kai Tone',
    path: '/m/1.mp3',
    duration: Duration(minutes: 3),
    version: 1,
  );

  Future<FakePlayer> openNowPlaying(WidgetTester tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2280)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player);
    await player.playSongs([song], source: PlaySource.songs);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();
    return player;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a preset starts a countdown shown as a ticking chip', (
    tester,
  ) async {
    final player = await openNowPlaying(tester);
    await tapAndSettle(tester, find.byTooltip('Sleep timer'));
    expect(
      find.text('Music fades out over 10 seconds, then pauses.'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('30 minutes'));

    expect(player.sleepState, isA<SleepCountdown>());
    expect(find.text('30:00'), findsOneWidget);
    // The chip sits on the same line as "Up next" on a 360 dp phone.
    expect(
      tester.getCenter(find.text('30:00')).dy,
      moreOrLessEquals(
        tester.getCenter(find.textContaining('Up next')).dy,
        epsilon: 2,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('29:59'), findsOneWidget);

    // The chip opens the sheet with the time left and a way to turn it off.
    await tapAndSettle(tester, find.text('29:59'));
    expect(find.text('Stops in 29:59'), findsOneWidget);
    await tapAndSettle(tester, find.text('Turn off'));
    expect(player.sleepState, isA<SleepTimerOff>());
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
  });

  testWidgets('end of this song', (tester) async {
    final player = await openNowPlaying(tester);
    await tapAndSettle(tester, find.byTooltip('Sleep timer'));
    await tapAndSettle(tester, find.text('End of this song'));
    expect(player.sleepState, isA<SleepAtEndOfTrack>());
    expect(find.text('End of song'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Sleep timer: Stops after this song'),
      findsOneWidget,
    );
  });

  testWidgets('custom length from the slider', (tester) async {
    final player = await openNowPlaying(tester);
    await tapAndSettle(tester, find.byTooltip('Sleep timer'));
    await tapAndSettle(tester, find.text('Custom…'));
    expect(find.text('20 minutes'), findsOneWidget);

    // Drag the slider to the far right: 3 hours.
    await tester.drag(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Slider),
      ),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 hours'), findsOneWidget);
    await tapAndSettle(tester, find.text('Start'));

    expect(find.text('3:00:00'), findsOneWidget);
    expect(player.sleepState, isA<SleepCountdown>());
  });

  test('labels', () {
    expect(sleepTimerLabel(const Duration(minutes: 15)), '15 minutes');
    expect(sleepTimerLabel(const Duration(hours: 1)), '1 hour');
    expect(sleepTimerLabel(const Duration(minutes: 95)), '1 h 35 min');
    final now = DateTime(2026);
    final state = SleepCountdown(
      endsAt: now.add(const Duration(milliseconds: 400)),
    );
    expect(sleepTimerText(state, now), '0:01');
    expect(sleepTimerText(state, now, long: true), 'Stops in 0:01');
  });
}
