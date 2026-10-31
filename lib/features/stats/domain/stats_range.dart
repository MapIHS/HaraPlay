/// The time range the Stats tab covers.
enum StatsRange {
  week('Week', 7),
  month('Month', 30),
  year('Year', 365),
  all('All time', null);

  const StatsRange(this.label, this.days);

  final String label;

  /// Number of calendar days, today included; null for all time.
  final int? days;

  /// Local midnight at the start of the range.
  DateTime since(DateTime now) {
    final days = this.days;
    if (days == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime(now.year, now.month, now.day - (days - 1));
  }
}

const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Tue 27 Oct", with the year when it isn't [now]'s year.
String formatDay(DateTime day, DateTime now) {
  final base =
      '${_shortWeekdays[day.weekday - 1]} ${day.day} ${shortMonths[day.month - 1]}';
  return day.year == now.year ? base : '$base ${day.year}';
}

/// "Today", "Yesterday" or [formatDay].
String dayHeading(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(day.year, day.month, day.day);
  final diff = today.difference(date).inHours;
  if (diff < 12 && diff > -12) return 'Today';
  if (diff >= 12 && diff < 36) return 'Yesterday';
  return formatDay(date, now);
}
