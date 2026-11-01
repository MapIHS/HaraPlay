import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/player/data/crossfade.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

QueueSong _song(
  int id, {
  String? album = 'Blue Hours',
  int? track,
  int? disc,
  int? albumId = 5,
  Duration duration = const Duration(seconds: 30),
}) => QueueSong(
  id: id,
  title: 'Song $id',
  path: '/m/$id.mp3',
  duration: duration,
  version: 1,
  albumId: albumId,
  trackNumber: track,
  discNumber: disc,
  taggedAlbum: album,
);

class _Host implements CrossfadeHost {
  @override
  Duration position = Duration.zero;
  @override
  bool playing = true;
  @override
  double outgoingVolume = 0.8;

  final ramps = <double>[];
  int jumps = 0;

  @override
  Future<void> setRamp(double ramp) async => ramps.add(ramp);

  @override
  Future<void> jumpToNext() async => jumps++;
}

class _Tail implements TailPlayer {
  _Tail(this.host);

  final _Host host;
  final loads = <Duration>[];
  final volumes = <double>[];
  bool _playing = false;
  bool stopped = false;
  bool disposed = false;

  @override
  Future<void> load(Uri uri, Duration position) async {
    loads.add(position);
    stopped = false;
  }

  @override
  Future<void> play() async => _playing = true;

  @override
  Future<void> pause() async => _playing = false;

  @override
  Future<void> stop() async {
    _playing = false;
    stopped = true;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  // In step with the main player.
  @override
  Duration get position => host.position;

  @override
  bool get playing => _playing;

  @override
  bool get started => _playing;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  group('when to stay gapless', () {
    test('only consecutive tracks of the same real album', () {
      expect(keepsGapless(_song(1, track: 4), _song(2, track: 5)), isTrue);
      expect(keepsGapless(_song(1, track: 4), _song(2, track: 6)), isFalse);
      expect(keepsGapless(_song(1, track: 4), _song(2, track: 4)), isFalse);
      expect(
        keepsGapless(_song(1, track: 9, disc: 1), _song(2, track: 10, disc: 2)),
        isFalse,
      );
      expect(
        keepsGapless(_song(1, track: 4), _song(2, track: 5, album: 'Other')),
        isFalse,
      );
      expect(
        keepsGapless(_song(1, track: 4), _song(2, track: 5, albumId: 6)),
        isFalse,
        reason: 'same name, different album',
      );
    });

    test('untagged songs, unknown albums and missing track numbers fade', () {
      expect(
        keepsGapless(
          _song(1, album: null, track: 1),
          _song(2, album: null, track: 2),
        ),
        isFalse,
      );
      expect(keepsGapless(_song(1), _song(2)), isFalse);
      expect(keepsGapless(_song(1, track: 1), _song(2)), isFalse);
    });

    test('an album named like its folder is not a real tag', () {
      expect(realAlbumTag('Music', folderName: 'music'), isNull);
      expect(realAlbumTag(' ', folderName: 'x'), isNull);
      expect(realAlbumTag(null, folderName: 'x'), isNull);
      expect(realAlbumTag('Blue Hours', folderName: 'Downloads'), 'Blue Hours');
    });
  });

  test('length and curves', () {
    const s6 = Duration(seconds: 6);
    expect(
      crossfadeLength(
        s6,
        const Duration(minutes: 3),
        const Duration(minutes: 3),
      ),
      s6,
    );
    expect(
      crossfadeLength(
        s6,
        const Duration(seconds: 8),
        const Duration(minutes: 3),
      ),
      const Duration(seconds: 4),
      reason: 'at most half a song',
    );
    expect(fadeInGain(0), 0);
    expect(fadeOutGain(0), 1);
    expect(fadeInGain(0.5), closeTo(0.7071, 1e-4));
    // Equal power: the summed power stays 1.
    for (final t in [0.1, 0.3, 0.7, 0.9]) {
      expect(
        fadeInGain(t) * fadeInGain(t) + fadeOutGain(t) * fadeOutGain(t),
        closeTo(1, 1e-9),
      );
    }
  });

  group('Crossfader', () {
    late _Host host;
    late _Tail tail;
    late Crossfader crossfader;
    final current = _song(1, track: 1);
    final next = _song(2, album: 'Other');

    void setUpFader({bool onSkip = false}) {
      host = _Host();
      tail = _Tail(host);
      crossfader = Crossfader(
        host: host,
        tailPlayer: () => tail,
        clock: () => clock.now(),
      )..configure((length: const Duration(seconds: 6), onSkip: onSkip));
    }

    Future<void> at(WidgetTester tester, int ms, {QueueSong? to}) async {
      host.position = Duration(milliseconds: ms);
      crossfader.onPosition(
        current: current,
        next: to ?? next,
        duration: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('prepares, lines up, hands over and fades', (tester) async {
      setUpFader();
      await at(tester, 17000);
      expect(tail.loads, isEmpty, reason: 'not yet in the window');

      await at(tester, 18500);
      expect(tail.loads, [const Duration(milliseconds: 22500)]);
      expect(tail.volumes.first, 0, reason: 'muted until the handover');

      await at(tester, 22600);
      await tester.pump(const Duration(milliseconds: 500));
      expect(crossfader.phase, 'synced');
      expect(host.jumps, 0);

      await at(tester, 24000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(host.jumps, 1);
      expect(crossfader.fading, isTrue);

      await tester.pump(const Duration(seconds: 3));
      expect(host.ramps.last, closeTo(0.7071, 0.05));
      expect(tail.volumes.last, closeTo(0.7071 * 0.8, 0.05));

      await tester.pump(const Duration(seconds: 4));
      expect(crossfader.fading, isFalse);
      expect(host.ramps.last, 1);
      expect(tail.stopped, isTrue);
    });

    testWidgets('consecutive album tracks stay gapless', (tester) async {
      setUpFader();
      await at(tester, 20000, to: _song(2, track: 2));
      await at(tester, 24000, to: _song(2, track: 2));
      expect(tail.loads, isEmpty);
      expect(host.jumps, 0);
    });

    testWidgets('a pause before the fade cancels; during it, both pause', (
      tester,
    ) async {
      setUpFader();
      await at(tester, 20000);
      await crossfader.onPause();
      expect(tail.stopped, isTrue);
      expect(host.ramps.last, 1);

      // Resumed later: it prepares again.
      await at(tester, 21000);
      await at(tester, 22600);
      await tester.pump(const Duration(milliseconds: 500));
      await at(tester, 24000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(crossfader.fading, isTrue);

      await tester.pump(const Duration(seconds: 2));
      await crossfader.onPause();
      expect(tail.playing, isFalse);
      final ramp = host.ramps.last;
      await tester.pump(const Duration(seconds: 20));
      expect(crossfader.fading, isTrue, reason: 'the fade waits');
      expect(host.ramps.last, ramp);

      await crossfader.onPlay(() => crossfader.currentLength);
      expect(tail.playing, isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(crossfader.fading, isFalse);
    });

    testWidgets('a seek or skip mid-fade stops the tail at once', (
      tester,
    ) async {
      setUpFader();
      await at(tester, 20000);
      await at(tester, 22600);
      await tester.pump(const Duration(milliseconds: 500));
      await at(tester, 24000);
      await tester.pump(const Duration(seconds: 1));
      await crossfader.cancel();
      expect(tail.stopped, isTrue);
      expect(host.ramps.last, 1);
      expect(crossfader.fading, isFalse);
    });

    testWidgets('manual skips fade only with "crossfade when skipping"', (
      tester,
    ) async {
      setUpFader();
      host.position = const Duration(seconds: 10);
      expect(await crossfader.skip(current: current, next: next), isFalse);

      setUpFader(onSkip: true);
      host.position = const Duration(seconds: 10);
      late bool skipped;
      unawaited(
        crossfader.skip(current: current, next: next).then((r) => skipped = r),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(skipped, isTrue);
      expect(tail.loads.single, const Duration(milliseconds: 10250));
      expect(host.jumps, 1);
      await tester.pump(const Duration(seconds: 7));
      expect(tail.stopped, isTrue);
    });

    testWidgets('off: nothing happens at all', (tester) async {
      setUpFader();
      crossfader.configure((length: Duration.zero, onSkip: true));
      await at(tester, 20000);
      await at(tester, 24000);
      expect(tail.loads, isEmpty);
      expect(await crossfader.skip(current: current, next: next), isFalse);
    });
  });

  testWidgets('Settings: crossfade length and the skip switch', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Off: songs follow each other gaplessly'), findsOneWidget);
    expect(find.text('Crossfade when skipping'), findsNothing);

    await tester.tap(find.text('Crossfade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 s'));
    await tester.pumpAndSettle();
    expect(player.crossfade.length, const Duration(seconds: 6));
    expect(find.text('6 s · Songs blend into each other'), findsOneWidget);

    await tester.tap(find.text('Crossfade when skipping'));
    await tester.pumpAndSettle();
    expect(player.crossfade.onSkip, isTrue);
    expect(find.text('Skipping to the next song fades too'), findsOneWidget);
  });
}
