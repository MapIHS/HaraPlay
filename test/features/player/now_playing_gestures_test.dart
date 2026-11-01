import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';
import 'package:haraplay/features/player/presentation/peek_artwork.dart';
import 'package:haraplay/features/player/presentation/seek_bar.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

QueueSong _song(int id) => QueueSong(
  id: id,
  title: 'Song $id',
  artist: 'Mono Lisa',
  album: 'Midnight',
  path: '/m/$id.mp3',
  duration: const Duration(minutes: 3),
  version: 1,
);

void main() {
  final songs = [_song(1), _song(2), _song(3)];

  Future<FakePlayer> openNowPlaying(
    WidgetTester tester, {
    int startIndex = 1,
    bool waveMotion = false,
  }) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player, waveMotion: waveMotion);
    await player.playSongs(
      songs,
      startIndex: startIndex,
      source: PlaySource.album,
    );
    await tester.pump();
    await tester.tap(find.byType(MiniPlayer));
    // A moving wave never settles; give the panel its time instead.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return player;
  }

  Finder artwork() => find.byType(PeekArtwork);
  double artWidth(WidgetTester tester) => tester.getSize(artwork()).width;

  group('peek swipe', () {
    testWidgets('a short drag springs back; past 35% it changes song', (
      tester,
    ) async {
      final player = await openNowPlaying(tester);
      final width = artWidth(tester);

      await tester.drag(artwork(), Offset(-width * 0.25, 0));
      await tester.pumpAndSettle();
      expect(player.currentIndex, 1);

      await tester.drag(artwork(), Offset(-width * 0.5, 0));
      await tester.pumpAndSettle();
      expect(player.currentIndex, 2);
      expect(find.text('Song 3'), findsWidgets);
      expect(player.nexts, 0, reason: 'goes to the peeked song directly');
    });

    testWidgets('the neighbour follows the finger', (tester) async {
      await openNowPlaying(tester);
      bool shown(int id) => tester
          .widget<Visibility>(
            find.ancestor(
              of: find.byKey(ValueKey(id)),
              matching: find.byType(Visibility),
            ),
          )
          .visible;
      expect((shown(1), shown(3)), (false, false));

      final gesture = await tester.startGesture(tester.getCenter(artwork()));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect((shown(1), shown(3)), (false, true));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      expect((shown(1), shown(3)), (true, false));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a right swipe goes back a song even late in the song', (
      tester,
    ) async {
      final player = await openNowPlaying(tester);
      player.emitPosition(const Duration(seconds: 40));
      await tester.pumpAndSettle();

      await tester.drag(artwork(), Offset(artWidth(tester) * 0.5, 0));
      await tester.pumpAndSettle();
      expect(player.currentIndex, 0);
      expect(player.previouses, 0);
    });

    testWidgets('a fling changes song even when short', (tester) async {
      final player = await openNowPlaying(tester);
      await tester.fling(artwork(), const Offset(-60, 0), 1500);
      await tester.pumpAndSettle();
      expect(player.currentIndex, 2);
    });

    testWidgets('at the end of the queue it only stretches', (tester) async {
      final player = await openNowPlaying(tester, startIndex: 2);
      await tester.drag(artwork(), Offset(-artWidth(tester) * 0.8, 0));
      await tester.pumpAndSettle();
      expect(player.currentIndex, 2);

      // Under repeat all the first song is next.
      await player.setRepeat(RepeatSetting.all);
      await tester.pumpAndSettle();
      await tester.drag(artwork(), Offset(-artWidth(tester) * 0.5, 0));
      await tester.pumpAndSettle();
      expect(player.currentIndex, 0);
    });
  });

  group('double-tap', () {
    Future<void> doubleTap(WidgetTester tester, {required bool right}) async {
      final rect = tester.getRect(artwork());
      final at = Offset(
        right ? rect.right - 30 : rect.left + 30,
        rect.center.dy,
      );
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(at);
      await tester.pump(kDoubleTapMinTime);
    }

    testWidgets('the right half seeks forward, the left half back', (
      tester,
    ) async {
      final player = await openNowPlaying(tester);
      player.emitPosition(const Duration(seconds: 30));
      await tester.pump();

      await doubleTap(tester, right: true);
      expect(player.seeks.last, const Duration(seconds: 40));
      expect(find.text('+10 s'), findsOneWidget);

      // Quick repeats add up, before the position catches up.
      await tester.pump(const Duration(milliseconds: 200));
      await doubleTap(tester, right: true);
      expect(player.seeks.last, const Duration(seconds: 50));
      expect(find.text('+20 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      player.emitPosition(const Duration(seconds: 5));
      await tester.pump();
      await doubleTap(tester, right: false);
      expect(player.seeks.last, Duration.zero, reason: 'clamped at 0:00');
      expect(find.text('−10 s'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(player.currentIndex, 1, reason: 'taps never change song');
    });
  });

  group('wavy seek bar', () {
    Finder track() => find.byKey(SeekBar.trackKey);

    testWidgets('scrubbing previews the time and seeks once on release', (
      tester,
    ) async {
      final player = await openNowPlaying(tester);
      final rect = tester.getRect(track());
      final gesture = await tester.startGesture(rect.centerLeft);
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveTo(rect.center);
      await tester.pump();
      expect(player.seeks, isEmpty);
      expect(find.text('1:30'), findsOneWidget);
      expect(find.text('-1:30'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(player.seeks.single.inSeconds, inInclusiveRange(88, 92));
    });

    testWidgets('accessibility steps by 10 seconds', (tester) async {
      final semantics = tester.ensureSemantics();
      final player = await openNowPlaying(tester);
      player.emitPosition(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.bySemanticsLabel('Seek'));
      expect(node.value, '0:30 of 3:00');
      expect(node.increasedValue, '0:40 of 3:00');
      tester.semantics.increase(find.semantics.byLabel('Seek'));
      await tester.pump();
      expect(player.seeks.last, const Duration(seconds: 40));
      semantics.dispose();
    });

    testWidgets('the wave moves only while playing and not scrubbing', (
      tester,
    ) async {
      final player = await openNowPlaying(tester, waveMotion: true);
      // Playing: the wave keeps animating, so frames keep coming.
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Scrubbing flattens it; once flat, nothing animates any more.
      final gesture = await tester.startGesture(
        tester.getRect(track()).centerLeft,
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Paused: flat and still, so the test can settle.
      await player.togglePlay();
      await tester.pumpAndSettle();
      expect(player.currentStatus.playing, isFalse);
    });
  });
}
