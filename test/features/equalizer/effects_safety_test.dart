import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/equalizer/data/audio_effects.dart';
import 'package:haraplay/features/player/presentation/stop_on_task_removed.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

class _Log {
  final calls = <String>[];
  final ducks = <double>[];
}

class _FakeEqualizer implements EqualizerControl {
  _FakeEqualizer(this.log);

  final _Log log;
  @override
  bool get ready => true;

  @override
  Future<void> setEnabled(bool enabled) async =>
      log.calls.add('eq.enabled=$enabled');

  @override
  Future<void> setGains(List<double> gains) async =>
      log.calls.add('eq.gains=${gains.join(',')}');
}

class _FakeLoudness implements LoudnessControl {
  _FakeLoudness(this.log);

  final _Log log;

  @override
  Future<void> setEnabled(bool enabled) async =>
      log.calls.add('loud.enabled=$enabled');

  @override
  Future<void> setTargetGain(double db) async => log.calls.add('loud.gain=$db');
}

void main() {
  group('JustAudioEffects never switches an effect off', () {
    late _Log log;
    late JustAudioEffects effects;

    setUp(() {
      log = _Log();
      effects = JustAudioEffects(
        equalizer: _FakeEqualizer(log),
        loudness: _FakeLoudness(log),
      );
    });

    Future<void> apply(bool on, List<double> gains, double loud) =>
        effects.apply(equalizerEnabled: on, gains: gains, loudnessDb: loud);

    test('an unused effect is never touched', () async {
      await apply(false, [6, 3, 0], 0);
      expect(log.calls, isEmpty);
    });

    test('on: curve first, then switched on; off: a flat curve', () async {
      expect(effects.switchesOn(equalizerEnabled: true, loudnessDb: 0), isTrue);
      await apply(true, [6, 3, 0], 0);
      expect(log.calls, ['eq.gains=6.0,3.0,0.0', 'eq.enabled=true']);
      expect(
        effects.switchesOn(equalizerEnabled: true, loudnessDb: 0),
        isFalse,
        reason: 'already on',
      );

      log.calls.clear();
      await apply(false, [6, 3, 0], 0);
      await apply(true, [-2, 0, 4], 0); // a preset change
      expect(log.calls, ['eq.gains=0.0,0.0,0.0', 'eq.gains=-2.0,0.0,4.0']);
      expect(log.calls, isNot(contains('eq.enabled=false')));
    });

    test('loudness: switched on once, then only its gain moves', () async {
      await apply(false, const [], 6);
      await apply(false, const [], 0);
      await apply(false, const [], 3);
      expect(log.calls, [
        'loud.gain=6.0',
        'loud.enabled=true',
        'loud.gain=0.0',
        'loud.gain=3.0',
      ]);
    });
  });

  group('EffectsChangeGuard', () {
    late _Log log;
    late bool playing;

    EffectsChangeGuard guard() => EffectsChangeGuard(
      isPlaying: () => playing,
      setDuck: (v) async {
        log.ducks.add(v);
        log.calls.add('duck');
      },
      pause: () async => log.calls.add('pause'),
      play: () async => log.calls.add('play'),
      beforeChange: () async => log.calls.add('stop crossfade'),
      wait: (_) async {},
    );

    Future<void> change() async => log.calls.add('change');

    /// The calls with consecutive volume steps collapsed into one "duck".
    List<String> steps() => [
      for (final (i, c) in log.calls.indexed)
        if (c != 'duck' || i == 0 || log.calls[i - 1] != 'duck') c,
    ];

    setUp(() {
      log = _Log();
      playing = true;
    });

    test(
      'while playing: silence, change, back up to (never above) full',
      () async {
        await guard().run(change, switchesOn: false);
        expect(steps(), ['stop crossfade', 'duck', 'change', 'duck']);
        // Down to silence step by step, then up again, never above full.
        final bottom = log.ducks.indexOf(0);
        for (var k = 1; k <= bottom; k++) {
          expect(log.ducks[k], lessThan(log.ducks[k - 1]));
        }
        for (var k = bottom + 1; k < log.ducks.length; k++) {
          expect(log.ducks[k], greaterThan(log.ducks[k - 1]));
        }
        expect(log.ducks.every((v) => v >= 0 && v <= 1), isTrue);
        final up = log.ducks.sublist(bottom + 1);
        expect(up.last, 1);
      },
    );

    test('switching an effect on pauses playback around it', () async {
      await guard().run(change, switchesOn: true);
      expect(steps(), [
        'stop crossfade',
        'duck',
        'pause',
        'change',
        'play',
        'duck',
      ]);
    });

    test('nothing playing, or a band being dragged: just the change', () async {
      playing = false;
      await guard().run(change, switchesOn: true);
      playing = true;
      await guard().run(change, switchesOn: false, smooth: false);
      expect(log.calls, ['change', 'change']);
    });

    test('a failing change still brings the volume back', () async {
      await expectLater(
        guard().run(
          () async => throw StateError('effect busy'),
          switchesOn: true,
        ),
        throwsStateError,
      );
      expect(log.calls, contains('play'));
      expect(log.ducks.last, 1);
    });

    test('changes run one at a time', () async {
      final g = guard();
      await Future.wait([
        g.run(() async => log.calls.add('first'), switchesOn: false),
        g.run(() async => log.calls.add('second'), switchesOn: false),
      ]);
      final calls = steps();
      expect(calls.indexOf('second'), greaterThan(calls.indexOf('first') + 1));
      expect(log.ducks.last, 1);
    });

    test('GuardedAudioEffects pauses only for the first switch-on', () async {
      final effects = JustAudioEffects(equalizer: _FakeEqualizer(_Log()));
      final guarded = GuardedAudioEffects(effects, guard());
      await guarded.apply(equalizerEnabled: true, gains: [3], loudnessDb: 0);
      await guarded.apply(equalizerEnabled: false, gains: [3], loudnessDb: 0);
      await guarded.apply(equalizerEnabled: true, gains: [3], loudnessDb: 0);
      expect(log.calls.where((c) => c == 'pause'), hasLength(1));
    });
  });

  testWidgets('Settings: "Stop when removed from Recent apps"', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Stop when removed from Recent apps'),
      200,
    );
    expect(
      find.text('Music keeps playing; a paused player always closes'),
      findsOneWidget,
    );
    await tester.tap(find.text('Stop when removed from Recent apps'));
    await tester.pumpAndSettle();
    expect(player.stopOnTaskRemoved, isTrue);
    expect(find.text('Swiping HaraPlay away stops the music'), findsOneWidget);
    final prefs = await createTestPreferences();
    expect(loadStopOnTaskRemoved(prefs), isFalse, reason: 'off by default');
  });
}
