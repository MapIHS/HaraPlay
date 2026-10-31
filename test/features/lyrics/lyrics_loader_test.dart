import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/lyrics/data/lyrics_loader.dart';
import 'package:haraplay/features/lyrics/domain/lyrics.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('lyrics'));
  tearDown(() => dir.delete(recursive: true));

  String audio(String name) {
    // Not real audio: embedded lyrics can't be read from it.
    final file = File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3]);
    return file.path;
  }

  test('a .lrc file with the same base name is used', () {
    final path = audio('Song.mp3');
    File('${dir.path}/Song.lrc').writeAsStringSync('[00:01.00]hello');
    final lyrics = loadLyrics(path)!;
    expect(lyrics.source, LyricsSource.sidecar);
    expect(lyrics.synced, isTrue);
    expect(lyrics.lines.single.text, 'hello');
  });

  test('an upper-case .LRC extension is found too', () {
    final path = audio('Loud.flac');
    File('${dir.path}/Loud.LRC').writeAsStringSync('plain words');
    expect(loadLyrics(path)!.lines.single.text, 'plain words');
  });

  test('no sidecar and unreadable tags: no lyrics', () {
    expect(loadLyrics(audio('Nothing.mp3')), isNull);
    expect(loadLyrics('${dir.path}/missing.mp3'), isNull);
  });

  test('an empty sidecar is ignored', () {
    final path = audio('Blank.mp3');
    File('${dir.path}/Blank.lrc').writeAsStringSync('[ar:Someone]\n\n');
    expect(loadLyrics(path), isNull);
  });

  test('sidecar paths only replace the extension', () {
    expect(sidecarPaths('/m/a.b/Song.v2.mp3'), [
      '/m/a.b/Song.v2.lrc',
      '/m/a.b/Song.v2.LRC',
    ]);
    expect(sidecarPaths('/m/a.b/NoExt'), [
      '/m/a.b/NoExt.lrc',
      '/m/a.b/NoExt.LRC',
    ]);
  });

  group('decodeLyricsText', () {
    const text = 'Señorita · ♪';
    test('UTF-8 with and without BOM', () {
      final bytes = utf8.encode(text);
      expect(decodeLyricsText(Uint8List.fromList(bytes)), text);
      expect(
        decodeLyricsText(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes])),
        text,
      );
    });

    test('UTF-16 little and big endian with BOM', () {
      final le = <int>[0xFF, 0xFE];
      final be = <int>[0xFE, 0xFF];
      for (final unit in text.codeUnits) {
        le.addAll([unit & 0xFF, unit >> 8]);
        be.addAll([unit >> 8, unit & 0xFF]);
      }
      expect(decodeLyricsText(Uint8List.fromList(le)), text);
      expect(decodeLyricsText(Uint8List.fromList(be)), text);
    });

    test('Latin-1 when the bytes are not valid UTF-8', () {
      final bytes = latin1.encode('Señorita café');
      expect(decodeLyricsText(Uint8List.fromList(bytes)), 'Señorita café');
    });
  });
}
