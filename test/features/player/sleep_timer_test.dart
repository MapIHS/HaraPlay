import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/player/data/sleep_timer.dart';
import 'package:haraplay/features/player/domain/sleep_timer_state.dart';

void main() {
  late List<double> volumes;
  late int pauses;
  late SleepTimer timer;

  setUp(() {
    volumes = [];
    pauses = 0;
    timer = SleepTimer(
      setVolume: (v) async => volumes.add(v),
      pause: () async => pauses++,
    );
  });

  bool nonIncreasing(List<double> values) {
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[i - 1] + 1e-9) return false;
    }
    return true;
  }

  test('a countdown plays at full volume, fades over the last 10 s, '
      'pauses and restores the volume', () {
    fakeAsync((async) {
      timer.start(const Duration(minutes: 15));
      expect(timer.state, isA<SleepCountdown>());

      async.elapse(const Duration(minutes: 14, seconds: 49));
      expect(volumes, isEmpty);
      expect((timer.state as SleepCountdown).fading, isFalse);

      async.elapse(const Duration(seconds: 2));
      expect((timer.state as SleepCountdown).fading, isTrue);
      async.elapse(const Duration(seconds: 5));
      expect(volumes.last, inExclusiveRange(0.1, 0.9));
      expect(pauses, 0);

      async.elapse(const Duration(seconds: 4));
      expect(pauses, 1);
      expect(timer.state, isA<SleepTimerOff>());
      // Faded down to silence, then restored after the pause.
      final fade = volumes.sublist(0, volumes.length - 1);
      expect(nonIncreasing(fade), isTrue);
      expect(fade.last, 0);
      expect(volumes.last, 1);
    });
  });

  test('the countdown reports the time left', () {
    fakeAsync((async) {
      timer.start(const Duration(minutes: 30));
      async.elapse(const Duration(minutes: 12, seconds: 30));
      final state = timer.state as SleepCountdown;
      expect(
        state.remainingAt(clock.now()),
        const Duration(minutes: 17, seconds: 30),
      );
      expect(
        state.remainingAt(state.endsAt.add(const Duration(seconds: 3))),
        Duration.zero,
      );
    });
  });

  test('a timer shorter than the fade fades over its whole length', () {
    fakeAsync((async) {
      timer.start(const Duration(seconds: 4));
      async.elapse(const Duration(milliseconds: 100));
      expect((timer.state as SleepCountdown).fading, isTrue);
      async.elapse(const Duration(seconds: 4));
      expect(pauses, 1);
      expect(volumes.last, 1);
    });
  });

  test('cancel during the fade restores the volume and never pauses', () {
    fakeAsync((async) {
      timer.start(const Duration(minutes: 1));
      async.elapse(const Duration(seconds: 55));
      expect(volumes.last, lessThan(1));
      timer.cancel();
      expect(volumes.last, 1);
      async.elapse(const Duration(minutes: 5));
      expect(pauses, 0);
      expect(timer.state, isA<SleepTimerOff>());
    });
  });

  test('starting again replaces the running timer', () {
    fakeAsync((async) {
      timer.start(const Duration(minutes: 1));
      async.elapse(const Duration(seconds: 30));
      timer.start(const Duration(minutes: 1));
      async.elapse(const Duration(seconds: 45));
      expect(pauses, 0);
      async.elapse(const Duration(seconds: 20));
      expect(pauses, 1);
    });
  });

  test('end of song: fades over what is left, pauses when it ends', () {
    fakeAsync((async) {
      timer.startEndOfTrack();
      timer.trackRemaining(const Duration(seconds: 40));
      expect((timer.state as SleepAtEndOfTrack).fading, isFalse);

      timer.trackRemaining(const Duration(seconds: 8));
      expect((timer.state as SleepAtEndOfTrack).fading, isTrue);
      async.elapse(const Duration(seconds: 8));
      expect(volumes.last, 0);

      expect(timer.trackEnded(), isTrue);
      async.flushMicrotasks();
      expect(pauses, 1);
      expect(volumes.last, 1);
      expect(timer.state, isA<SleepTimerOff>());
      // Later songs end normally.
      expect(timer.trackEnded(), isFalse);
    });
  });

  test('end of song: seeking back out of the fade restores the volume', () {
    fakeAsync((async) {
      timer.startEndOfTrack();
      timer.trackRemaining(const Duration(seconds: 6));
      async.elapse(const Duration(seconds: 2));
      expect(volumes.last, lessThan(1));

      timer.trackRemaining(const Duration(minutes: 2));
      expect(volumes.last, 1);
      expect((timer.state as SleepAtEndOfTrack).fading, isFalse);
      async.elapse(const Duration(seconds: 10));
      expect(volumes.last, 1);
    });
  });

  test('states streams the current state first', () async {
    timer.startEndOfTrack();
    expect(await timer.states.first, isA<SleepAtEndOfTrack>());
    timer.cancel();
  });
}
