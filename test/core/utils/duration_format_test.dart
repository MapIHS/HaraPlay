import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/utils/duration_format.dart';

void main() {
  test('formats under an hour as m:ss', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 7)), '0:07');
    expect(formatDuration(const Duration(minutes: 3, seconds: 42)), '3:42');
    expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
  });

  test('formats an hour or more as h:mm:ss', () {
    expect(formatDuration(const Duration(hours: 1)), '1:00:00');
    expect(
      formatDuration(const Duration(hours: 2, minutes: 5, seconds: 9)),
      '2:05:09',
    );
  });

  test('drops milliseconds and keeps the sign for remaining time', () {
    expect(formatDuration(const Duration(milliseconds: 61999)), '1:01');
    expect(formatDuration(const Duration(minutes: -1, seconds: -5)), '-1:05');
  });
}
