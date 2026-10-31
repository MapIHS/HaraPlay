/// Where a song's lyrics came from.
enum LyricsSource {
  /// A `.lrc` file next to the audio file, with the same base name.
  sidecar,

  /// Lyrics stored in the audio file's tags.
  embedded,
}

/// One line of lyrics. [time] is set for synced lyrics.
class LyricLine {
  const LyricLine(this.text, {this.time});

  final String text;
  final Duration? time;

  @override
  bool operator ==(Object other) =>
      other is LyricLine && other.text == text && other.time == time;

  @override
  int get hashCode => Object.hash(text, time);

  @override
  String toString() => 'LyricLine(${time?.inMilliseconds}, $text)';
}

class Lyrics {
  const Lyrics({required this.lines, required this.synced, this.source});

  final List<LyricLine> lines;

  /// Every line has a time, in order.
  final bool synced;
  final LyricsSource? source;

  bool get isEmpty => lines.every((l) => l.text.trim().isEmpty);

  Lyrics withSource(LyricsSource source) =>
      Lyrics(lines: lines, synced: synced, source: source);

  /// Index of the line being sung at [position]: the last line that has
  /// started, or -1 before the first one. Always -1 for unsynced lyrics.
  int activeIndex(Duration position) {
    if (!synced || lines.isEmpty) return -1;
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].time! <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }
}

// [mm:ss], [mm:ss.x], [mm:ss.xx], [mm:ss.xxx] (also ':' before the
// fraction, which some editors write).
final _stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _tag = RegExp(r'^\[([a-zA-Z]+):(.*)\]$');

// Word-by-word timing of the "enhanced" LRC format: <mm:ss.xx>.
final _wordStamp = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');

/// Parses lyrics text. LRC timestamps make it synced; otherwise every line
/// is kept as plain text.
///
/// LRC details handled: several timestamps on one line (a repeated chorus),
/// `[offset:±ms]` (positive shows lines earlier), metadata tags such as
/// `[ar:]` (dropped), enhanced word timings (stripped), empty timed lines
/// (kept as pauses), and lines out of order (sorted).
Lyrics parseLyrics(String text) {
  final rawLines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceFirst('﻿', '')
      .split('\n');

  var offset = Duration.zero;
  final timed = <(Duration, int, String)>[];
  final plain = <String>[];
  for (final raw in rawLines) {
    final line = raw.trim();
    final stamps = <Duration>[];
    var rest = line;
    while (true) {
      final match = _stamp.matchAsPrefix(rest);
      if (match == null) break;
      stamps.add(_duration(match));
      rest = rest.substring(match.end).trimLeft();
    }
    if (stamps.isNotEmpty) {
      final words = rest.replaceAll(_wordStamp, '').trim();
      for (final time in stamps) {
        timed.add((time, timed.length, words));
      }
      continue;
    }
    final tag = _tag.firstMatch(line);
    if (tag != null) {
      if (tag[1]!.toLowerCase() == 'offset') {
        final ms = int.tryParse(tag[2]!.trim().replaceFirst('+', ''));
        if (ms != null) offset = Duration(milliseconds: ms);
      }
      continue;
    }
    plain.add(line);
  }

  if (timed.isEmpty) {
    // Unsynced: keep the text, trimming blank lines at both ends.
    while (plain.isNotEmpty && plain.first.isEmpty) {
      plain.removeAt(0);
    }
    while (plain.isNotEmpty && plain.last.isEmpty) {
      plain.removeLast();
    }
    return Lyrics(lines: [for (final l in plain) LyricLine(l)], synced: false);
  }

  // Stable sort by time (the index keeps file order for equal times).
  timed.sort((a, b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });
  return Lyrics(
    lines: [
      for (final (time, _, words) in timed)
        LyricLine(words, time: _shift(time, offset)),
    ],
    synced: true,
  );
}

Duration _duration(Match match) {
  final minutes = int.parse(match[1]!);
  final seconds = int.parse(match[2]!);
  final fraction = match[3];
  // ".5" is 500 ms, ".50" is 500 ms, ".500" is 500 ms.
  final ms = fraction == null
      ? 0
      : int.parse(fraction.padRight(3, '0').substring(0, 3));
  return Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
}

/// A positive offset makes lines appear earlier; never before zero.
Duration _shift(Duration time, Duration offset) {
  final shifted = time - offset;
  return shifted.isNegative ? Duration.zero : shifted;
}
