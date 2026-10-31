/// What the sleep timer is doing.
sealed class SleepTimerState {
  const SleepTimerState();

  bool get active => this is! SleepTimerOff;
}

class SleepTimerOff extends SleepTimerState {
  const SleepTimerOff();
}

/// Pauses at [endsAt]; the volume fades out over the last seconds.
class SleepCountdown extends SleepTimerState {
  const SleepCountdown({required this.endsAt, this.fading = false});

  final DateTime endsAt;
  final bool fading;

  Duration remainingAt(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

/// Pauses when the current song ends by itself.
class SleepAtEndOfTrack extends SleepTimerState {
  const SleepAtEndOfTrack({this.fading = false});

  final bool fading;
}
