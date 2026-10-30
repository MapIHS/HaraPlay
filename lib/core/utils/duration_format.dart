/// Formats a duration as `m:ss`, or `h:mm:ss` from one hour up.
/// Negative durations are formatted with a leading minus (for "−remaining").
String formatDuration(Duration duration) {
  final negative = duration.isNegative;
  final total = duration.abs().inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  final body = hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
  return negative ? '-$body' : body;
}

/// A total running time for headers: "42 min", "3 h 12 min", "1 h".
String formatTotalDuration(Duration duration) {
  final minutes = (duration.inSeconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}
