import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/lyrics/domain/lyrics.dart';

Duration ms(int value) => Duration(milliseconds: value);

void main() {
  test('timestamps in all common precisions', () {
    final lyrics = parseLyrics('''
[00:01]one
[00:02.5]two
[00:03.25]three
[00:04.125]four
[01:05:50]colon fraction''');
    expect(lyrics.synced, isTrue);
    expect(
      [for (final l in lyrics.lines) l.time],
      [ms(1000), ms(2500), ms(3250), ms(4125), ms(65500)],
    );
  });

  test('several timestamps on one line repeat it, sorted by time', () {
    final lyrics = parseLyrics('''
[00:10.00][00:30.00]chorus
[00:20.00]verse
[00:05.00]intro''');
    expect(lyrics.lines, [
      LyricLine('intro', time: ms(5000)),
      LyricLine('chorus', time: ms(10000)),
      LyricLine('verse', time: ms(20000)),
      LyricLine('chorus', time: ms(30000)),
    ]);
  });

  test('offset shifts every line, never below zero', () {
    final earlier = parseLyrics('[offset:+500]\n[00:00.20]a\n[00:02.00]b');
    expect([for (final l in earlier.lines) l.time], [ms(0), ms(1500)]);
    final later = parseLyrics('[offset:-250]\n[00:01.00]a');
    expect(later.lines.single.time, ms(1250));
  });

  test('metadata tags are dropped, empty timed lines kept as pauses', () {
    final lyrics = parseLyrics('''
[ti:Title]
[ar:Artist]
[length: 03:00]
[00:01.00]sing
[00:04.00]
[00:06.00]again''');
    expect(lyrics.lines.map((l) => l.text), ['sing', '', 'again']);
  });

  test('enhanced word timings are stripped', () {
    final lyrics = parseLyrics('[00:01.00]<00:01.00>Hello <00:01.50>there');
    expect(lyrics.lines.single.text, 'Hello there');
  });

  test('plain text stays unsynced, with outer blank lines trimmed', () {
    final lyrics = parseLyrics('\r\n﻿First line\r\n\r\nSecond line\r\n\r\n');
    expect(lyrics.synced, isFalse);
    expect(lyrics.lines.map((l) => l.text), ['First line', '', 'Second line']);
    expect(lyrics.activeIndex(ms(5000)), -1);
  });

  test('a BOM before the first timestamp is ignored', () {
    final lyrics = parseLyrics('﻿[00:01.00]start');
    expect(lyrics.synced, isTrue);
    expect(lyrics.lines.single.text, 'start');
  });

  test('activeIndex finds the line being sung', () {
    final lyrics = parseLyrics('[00:02]a\n[00:04]b\n[00:06]c');
    expect(lyrics.activeIndex(ms(0)), -1);
    expect(lyrics.activeIndex(ms(2000)), 0);
    expect(lyrics.activeIndex(ms(5999)), 1);
    expect(lyrics.activeIndex(ms(60000)), 2);
  });

  test('isEmpty for whitespace-only lyrics', () {
    expect(parseLyrics('  \n \n').isEmpty, isTrue);
    expect(parseLyrics('[00:01]').isEmpty, isTrue);
    expect(parseLyrics('hi').isEmpty, isFalse);
  });
}
