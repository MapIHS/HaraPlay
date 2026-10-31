import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../domain/lyrics.dart';

/// Finds a song's lyrics: a `.lrc` file next to it first, then lyrics in the
/// file's own tags (ID3 USLT, Vorbis LYRICS, MP4 ©lyr). Reading happens in
/// a short-lived isolate.
class LyricsLoader {
  const LyricsLoader();

  /// Null when the song has no (readable) lyrics.
  Future<Lyrics?> load(String audioPath) =>
      Isolate.run(() => loadLyrics(audioPath));
}

/// The synchronous lookup behind [LyricsLoader.load]. Never throws.
Lyrics? loadLyrics(String audioPath) {
  for (final candidate in sidecarPaths(audioPath)) {
    try {
      final file = File(candidate);
      if (!file.existsSync()) continue;
      final lyrics = parseLyrics(decodeLyricsText(file.readAsBytesSync()));
      if (!lyrics.isEmpty) return lyrics.withSource(LyricsSource.sidecar);
    } on FileSystemException {
      // Unreadable, e.g. Android 13+ only grants access to audio files.
    }
  }
  try {
    final text = readMetadata(File(audioPath)).lyrics;
    if (text == null) return null;
    final lyrics = parseLyrics(text.replaceAll('\u0000', ''));
    return lyrics.isEmpty ? null : lyrics.withSource(LyricsSource.embedded);
  } on Object {
    // Unsupported format or no read access.
    return null;
  }
}

/// "/m/Song.mp3" → "/m/Song.lrc" and "/m/Song.LRC".
List<String> sidecarPaths(String audioPath) {
  final slash = audioPath.lastIndexOf('/');
  final dot = audioPath.lastIndexOf('.');
  final base = dot > slash ? audioPath.substring(0, dot) : audioPath;
  return ['$base.lrc', '$base.LRC'];
}

/// Text of a lyrics file: UTF-8 or UTF-16 (with a byte-order mark), else
/// UTF-8, falling back to Latin-1 for older files.
String decodeLyricsText(Uint8List bytes) {
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _utf16(bytes.sublist(2), Endian.little);
    }
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes.sublist(2), Endian.big);
    }
  }
  final start =
      bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? 3
      : 0;
  final body = bytes.sublist(start);
  try {
    return utf8.decode(body);
  } on FormatException {
    return latin1.decode(body);
  }
}

String _utf16(Uint8List bytes, Endian endian) {
  final data = ByteData.sublistView(bytes);
  final units = [
    for (var i = 0; i + 1 < bytes.length; i += 2) data.getUint16(i, endian),
  ];
  return String.fromCharCodes(units);
}
