import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../../../core/utils/text_decode.dart';
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
      final lyrics = parseLyrics(decodeTextFile(file.readAsBytesSync()));
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
