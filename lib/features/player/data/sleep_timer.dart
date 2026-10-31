import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';

import '../domain/sleep_timer_state.dart';

/// Pauses playback after a while, fading the player's volume out first.
///
/// The audio handler drives it: it reports how much of the current song is
/// left ([trackRemaining]) and when a song ends by itself ([trackEnded]).
/// The fade changes only the player's own volume, never the system volume,
/// and the volume is restored once playback is paused or the timer is
/// cancelled.
class SleepTimer {
  SleepTimer({required this.setVolume, required this.pause});

  /// Length of the fade-out before pausing.
  static const fadeLength = Duration(seconds: 10);

  /// How often the volume steps during a fade.
  static const _fadeStep = Duration(milliseconds: 200);

  final Future<void> Function(double volume) setVolume;
  final Future<void> Function() pause;

  final _states = StreamController<SleepTimerState>.broadcast();
  SleepTimerState _state = const SleepTimerOff();
  Timer? _fadeStart;
  Timer? _fadeTick;
  Timer? _end;

  SleepTimerState get state => _state;

  /// The current state first, then every change.
  Stream<SleepTimerState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  /// Pauses [duration] from now. Replaces any running timer.
  void start(Duration duration) {
    _reset();
    final endsAt = clock.now().add(duration);
    _set(SleepCountdown(endsAt: endsAt));
    final fade = duration < fadeLength ? duration : fadeLength;
    _fadeStart = Timer(duration - fade, () {
      _set(SleepCountdown(endsAt: endsAt, fading: true));
      _fade(fade);
    });
    _end = Timer(duration, _finish);
  }

  /// Pauses when the current song ends by itself. Replaces any running
  /// timer.
  void startEndOfTrack() {
    _reset();
    _set(const SleepAtEndOfTrack());
  }

  /// Stops the timer and restores the volume.
  void cancel() {
    if (!_state.active) return;
    _reset();
    unawaited(setVolume(1));
    _set(const SleepTimerOff());
  }

  /// [remaining] of the current song is left to play (from the position
  /// updates). Starts the fade in end-of-song mode.
  void trackRemaining(Duration remaining) {
    final state = _state;
    if (state is! SleepAtEndOfTrack) return;
    if (state.fading) {
      // Seeked back out of the fade: the song isn't ending after all.
      if (remaining > fadeLength + const Duration(seconds: 1)) {
        _fadeTick?.cancel();
        unawaited(setVolume(1));
        _set(const SleepAtEndOfTrack());
      }
      return;
    }
    if (remaining > fadeLength) return;
    _set(const SleepAtEndOfTrack(fading: true));
    _fade(remaining);
  }

  /// The song ended by itself. Returns true when that ended the timer
  /// (playback was paused), so the handler can hold the next song at its
  /// start.
  bool trackEnded() {
    if (_state is! SleepAtEndOfTrack) return false;
    unawaited(_finish());
    return true;
  }

  Future<void> dispose() async {
    _reset();
    await _states.close();
  }

  /// Lowers the volume to silence over [length], on an ease-out curve so
  /// the quiet end lasts longest.
  void _fade(Duration length) {
    _fadeTick?.cancel();
    final started = clock.now();
    final total = math.max(length.inMilliseconds, 1);
    unawaited(setVolume(1));
    _fadeTick = Timer.periodic(_fadeStep, (timer) {
      final t = clock.now().difference(started).inMilliseconds / total;
      if (t >= 1) {
        timer.cancel();
        unawaited(setVolume(0));
        return;
      }
      final volume = math.cos(t * math.pi / 2);
      unawaited(setVolume(volume * volume));
    });
  }

  Future<void> _finish() async {
    _reset();
    _set(const SleepTimerOff());
    await setVolume(0);
    await pause();
    await setVolume(1);
  }

  void _reset() {
    _fadeStart?.cancel();
    _fadeTick?.cancel();
    _end?.cancel();
    _fadeStart = _fadeTick = _end = null;
  }

  void _set(SleepTimerState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}
