import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/audio_info/data/audio_header_reader.dart';
import 'package:haraplay/features/audio_info/domain/audio_info.dart';

/// Small helpers that build just enough of each format by hand.
class Bytes {
  final _b = BytesBuilder();

  Bytes ascii(String s) => this..addAll(latin1.encode(s));
  Bytes addAll(List<int> bytes) {
    _b.add(bytes);
    return this;
  }

  Bytes u8(int v) => this..addAll([v & 0xFF]);
  Bytes u16be(int v) => this..addAll([v >> 8 & 0xFF, v & 0xFF]);
  Bytes u24be(int v) => this..addAll([v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF]);
  Bytes u32be(int v) =>
      this..addAll([v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF]);
  Bytes u16le(int v) => this..addAll([v & 0xFF, v >> 8 & 0xFF]);
  Bytes u32le(int v) =>
      this..addAll([v & 0xFF, v >> 8 & 0xFF, v >> 16 & 0xFF, v >> 24 & 0xFF]);
  Bytes u64le(int v) => this
    ..u32le(v & 0xFFFFFFFF)
    ..u32le(v ~/ 0x100000000);
  Bytes zeros(int n) => this..addAll(List.filled(n, 0));

  Uint8List get bytes => _b.toBytes();
}

AudioFileInfo read(Uint8List bytes) => readAudioInfo(MemoryByteSource(bytes));

Uint8List vorbisComments(Map<String, String> tags) {
  final b = Bytes()
    ..u32le(4)
    ..ascii('test')
    ..u32le(tags.length);
  for (final MapEntry(:key, :value) in tags.entries) {
    final entry = utf8.encode('$key=$value');
    b
      ..u32le(entry.length)
      ..addAll(entry);
  }
  return b.bytes;
}

Uint8List flac({
  int rate = 96000,
  int channels = 2,
  int bits = 24,
  int samples = 96000 * 10,
  Map<String, String> tags = const {},
  int audioBytes = 1000,
}) {
  final info = Bytes()
    ..u16be(4096)
    ..u16be(4096)
    ..u24be(0)
    ..u24be(0)
    // 20 bits rate, 3 bits channels-1, 5 bits bits-1, 36 bits samples.
    ..u8(rate >> 12)
    ..u8(rate >> 4)
    ..u8((rate & 0x0F) << 4 | (channels - 1) << 1 | (bits - 1) >> 4)
    ..u8(((bits - 1) & 0x0F) << 4 | (samples ~/ 0x100000000) & 0x0F)
    ..u32be(samples & 0xFFFFFFFF)
    ..zeros(16);
  final comments = vorbisComments(tags);
  return (Bytes()
        ..ascii('fLaC')
        ..u8(0)
        ..u24be(34)
        ..addAll(info.bytes)
        ..u8(0x80 | 4)
        ..u24be(comments.length)
        ..addAll(comments)
        ..zeros(audioBytes))
      .bytes;
}

/// An ID3v2.3 tag with TXXX frames (Latin-1).
Uint8List id3v23(Map<String, String> txxx) {
  final frames = Bytes();
  for (final MapEntry(:key, :value) in txxx.entries) {
    final body =
        (Bytes()
              ..u8(0)
              ..ascii(key)
              ..u8(0)
              ..ascii(value))
            .bytes;
    frames
      ..ascii('TXXX')
      ..u32be(body.length)
      ..u16be(0)
      ..addAll(body);
  }
  frames.zeros(32); // padding
  final size = frames.bytes.length;
  return (Bytes()
        ..ascii('ID3')
        ..u8(3)
        ..u8(0)
        ..u8(0)
        ..u8(size >> 21 & 0x7F)
        ..u8(size >> 14 & 0x7F)
        ..u8(size >> 7 & 0x7F)
        ..u8(size & 0x7F)
        ..addAll(frames.bytes))
      .bytes;
}

/// MPEG-1 Layer III frames at 44.1 kHz, stereo, 128 kbps (417 bytes),
/// the first one optionally a Xing header.
Uint8List mp3Frames({int count = 5, int? xingFrames, int? xingBytes}) {
  final b = Bytes();
  for (var i = 0; i < count; i++) {
    final frame = Bytes()
      ..addAll([0xFF, 0xFB, 0x90, 0x00])
      ..zeros(32);
    if (i == 0 && xingFrames != null) {
      frame
        ..ascii('Xing')
        ..u32be(xingBytes == null ? 1 : 3)
        ..u32be(xingFrames);
      if (xingBytes != null) frame.u32be(xingBytes);
    }
    final bytes = frame.bytes;
    b
      ..addAll(bytes)
      ..zeros(417 - bytes.length);
  }
  return b.bytes;
}

Uint8List box(String type, List<int> body) =>
    (Bytes()
          ..u32be(8 + body.length)
          ..ascii(type)
          ..addAll(body))
        .bytes;

Uint8List fullBox(String type, List<int> body) =>
    box(type, [0, 0, 0, 0, ...body]);

Uint8List mp4({
  int rate = 44100,
  int channels = 2,
  int avgBitrate = 256000,
  Map<String, String> freeform = const {},
  int mdatBytes = 0,
  bool moovFirst = false,
}) {
  final esds = fullBox('esds', [
    0x03, 25, 0, 1, 0, // ES_Descriptor, ES_ID, flags
    0x04, 17, 0x40, 0x15, 0, 0, 0, // AAC, audio, buffer size
    ...(Bytes()
          ..u32be(320000)
          ..u32be(avgBitrate))
        .bytes,
    0x05, 2, 0x12, 0x10, // DecoderSpecificInfo
  ]);
  final mp4a = box('mp4a', [
    ...List.filled(6, 0), 0, 1, // reserved, data reference
    ...List.filled(8, 0), // version, revision, vendor
    ...(Bytes()
          ..u16be(channels)
          ..u16be(16)
          ..u16be(0)
          ..u16be(0)
          ..u32be(rate << 16))
        .bytes,
    ...esds,
  ]);
  final stsd = fullBox('stsd', [0, 0, 0, 1, ...mp4a]);
  final mdhd = fullBox('mdhd', [
    ...List.filled(8, 0),
    ...(Bytes()
          ..u32be(rate)
          ..u32be(rate * 10))
        .bytes,
    0,
    0,
    0,
    0,
  ]);
  final hdlr = fullBox('hdlr', [
    0,
    0,
    0,
    0,
    ...latin1.encode('soun'),
    ...List.filled(13, 0),
  ]);
  final trak = box(
    'trak',
    box('mdia', [...mdhd, ...hdlr, ...box('minf', box('stbl', stsd))]),
  );
  final items = <int>[];
  for (final MapEntry(:key, :value) in freeform.entries) {
    items.addAll(
      box('----', [
        ...fullBox('mean', latin1.encode('com.apple.iTunes')),
        ...fullBox('name', latin1.encode(key)),
        ...box('data', [0, 0, 0, 1, 0, 0, 0, 0, ...utf8.encode(value)]),
      ]),
    );
  }
  final udta = box(
    'udta',
    fullBox('meta', [
      ...fullBox('hdlr', List.filled(21, 0)),
      ...box('ilst', items),
    ]),
  );
  final moov = box('moov', [
    ...box('mvhd', List.filled(100, 0)),
    ...trak,
    ...udta,
  ]);
  final ftyp = box('ftyp', latin1.encode('M4A \x00\x00\x02\x00isom'));
  final mdat = box('mdat', List.filled(mdatBytes, 0));
  return Uint8List.fromList([
    ...ftyp,
    ...(moovFirst ? moov : mdat),
    ...(moovFirst ? mdat : moov),
  ]);
}

/// One Ogg page holding whole [packets].
Uint8List oggPage(
  List<Uint8List> packets, {
  int granule = 0,
  int serial = 7,
  int sequence = 0,
}) {
  final table = <int>[];
  for (final p in packets) {
    var left = p.length;
    while (left >= 255) {
      table.add(255);
      left -= 255;
    }
    table.add(left);
  }
  return (Bytes()
        ..ascii('OggS')
        ..u8(0)
        ..u8(0)
        ..u64le(granule)
        ..u32le(serial)
        ..u32le(sequence)
        ..u32le(0)
        ..u8(table.length)
        ..addAll(table)
        ..addAll([for (final p in packets) ...p]))
      .bytes;
}

void main() {
  group('FLAC', () {
    test('reads STREAMINFO, bitrate and ReplayGain comments', () {
      final info = read(
        flac(
          tags: {
            'replaygain_track_gain': '-7.25 dB',
            'REPLAYGAIN_TRACK_PEAK': '0.988251',
            'REPLAYGAIN_ALBUM_GAIN': '-6.10 dB',
            'TITLE': 'x',
          },
          audioBytes: 120000,
        ),
      );
      expect(info.codec, 'FLAC');
      expect(info.sampleRate, 96000);
      expect(info.bitDepth, 24);
      expect(info.channels, 2);
      expect(info.bitrate, 120000 * 8 ~/ 10);
      expect(info.replayGain.trackGain, -7.25);
      expect(info.replayGain.trackPeak, 0.988251);
      expect(info.replayGain.albumGain, -6.1);
      expect(info.replayGain.albumPeak, isNull);
      expect(techBadge(info), 'FLAC · 24-bit / 96 kHz');
    });

    test('after an ID3 tag', () {
      final bytes = Uint8List.fromList([
        ...id3v23(const {}),
        ...flac(rate: 44100, bits: 16),
      ]);
      expect(techBadge(read(bytes)), 'FLAC · 16-bit / 44.1 kHz');
    });

    test('a truncated file is unreadable, not an error', () {
      final bytes = flac();
      expect(read(Uint8List.sublistView(bytes, 0, 20)).codec, isNull);
    });
  });

  group('MP3', () {
    test('a CBR file uses the frame header', () {
      final info = read(
        Uint8List.fromList([...id3v23(const {}), ...mp3Frames()]),
      );
      expect(info.codec, 'MP3');
      expect(info.sampleRate, 44100);
      expect(info.channels, 2);
      expect(info.bitrate, 128000);
      expect(techBadge(info), 'MP3 · 128 kbps');
    });

    test('a Xing header gives the VBR average', () {
      // 1000 frames of 1152 samples at 44.1 kHz = 26.12 s; 600000 bytes.
      final info = read(mp3Frames(xingFrames: 1000, xingBytes: 600000));
      expect(info.bitrate, closeTo(600000 * 8 / (1000 * 1152 / 44100), 1));
    });

    test('ReplayGain from ID3v2.3 TXXX frames', () {
      final info = read(
        Uint8List.fromList([
          ...id3v23({
            'replaygain_track_gain': '-8.40 dB',
            'REPLAYGAIN_ALBUM_GAIN': '+1.50 dB',
            'REPLAYGAIN_ALBUM_PEAK': '1.000000',
          }),
          ...mp3Frames(),
        ]),
      );
      expect(info.replayGain.trackGain, -8.4);
      expect(info.replayGain.albumGain, 1.5);
      expect(info.replayGain.albumPeak, 1.0);
    });

    test('ReplayGain from an ID3v2.4 UTF-16 TXXX frame', () {
      final body = <int>[
        1, // UTF-16 with BOM
        0xFF,
        0xFE,
        ...[
          for (final c in 'REPLAYGAIN_TRACK_GAIN'.codeUnits) ...[c, 0],
        ],
        0,
        0,
        0xFF,
        0xFE,
        ...[
          for (final c in '-3.20 dB'.codeUnits) ...[c, 0],
        ],
      ];
      final size = 10 + body.length;
      final tag = [
        ...latin1.encode('ID3'),
        4,
        0,
        0,
        0,
        0,
        size >> 7 & 0x7F,
        size & 0x7F,
        ...latin1.encode('TXXX'),
        0,
        0,
        body.length >> 7 & 0x7F,
        body.length & 0x7F,
        0,
        0,
        ...body,
      ];
      final info = read(Uint8List.fromList([...tag, ...mp3Frames()]));
      expect(info.codec, 'MP3');
      expect(info.replayGain.trackGain, -3.2);
    });

    test('ReplayGain from an APEv2 tag at the end', () {
      final value = utf8.encode('-5.00 dB');
      final item = [
        ...(Bytes()
              ..u32le(value.length)
              ..u32le(0))
            .bytes,
        ...latin1.encode('REPLAYGAIN_TRACK_GAIN'),
        0,
        ...value,
      ];
      final footer =
          (Bytes()
                ..ascii('APETAGEX')
                ..u32le(2000)
                ..u32le(item.length + 32)
                ..u32le(1)
                ..u32le(0)
                ..zeros(8))
              .bytes;
      final info = read(
        Uint8List.fromList([...mp3Frames(), ...item, ...footer]),
      );
      expect(info.replayGain.trackGain, -5.0);
    });

    test('random bytes are unreadable', () {
      expect(
        read(Uint8List.fromList(List.generate(4000, (i) => i * 7 % 251))).codec,
        isNull,
      );
    });
  });

  group('MP4', () {
    test('AAC with the moov at the end and freeform ReplayGain', () {
      final info = read(
        mp4(
          freeform: {
            'replaygain_track_gain': '-4.20 dB',
            'replaygain_album_gain': '-5.30 dB',
          },
          mdatBytes: 50000,
        ),
      );
      expect(info.codec, 'AAC');
      expect(info.sampleRate, 44100);
      expect(info.channels, 2);
      // From the mdat size over 10 s.
      expect(info.bitrate, 40000);
      expect(info.replayGain.trackGain, -4.2);
      expect(info.replayGain.albumGain, -5.3);
      expect(techBadge(info), 'AAC · 40 kbps');
    });

    test('falls back to the esds bitrate without media data', () {
      final info = read(mp4(moovFirst: true));
      expect(info.bitrate, 256000);
    });
  });

  group('Ogg', () {
    test('Opus with R128 gain and a duration from the last page', () {
      final head =
          (Bytes()
                ..ascii('OpusHead')
                ..u8(1)
                ..u8(2)
                ..u16le(312)
                ..u32le(44100)
                ..u16le(0)
                ..u8(0))
              .bytes;
      final tags = Uint8List.fromList([
        ...latin1.encode('OpusTags'),
        ...vorbisComments({
          'R128_TRACK_GAIN': '-1792',
          'R128_ALBUM_GAIN': '256',
        }),
      ]);
      final bytes = Uint8List.fromList([
        ...oggPage([head]),
        ...oggPage([tags], sequence: 1),
        ...oggPage([Uint8List(20000)], granule: 312 + 48000 * 2, sequence: 2),
      ]);
      final info = read(bytes);
      expect(info.codec, 'Opus');
      expect(info.sampleRate, 48000);
      expect(info.channels, 2);
      expect(info.bitrate, closeTo(bytes.length * 8 / 2, 1));
      expect(info.replayGain.trackGain, -2.0); // −7 dB + 5 dB
      expect(info.replayGain.albumGain, 6.0);
    });

    test('Vorbis with a comment packet spanning pages', () {
      final id =
          (Bytes()
                ..u8(1)
                ..ascii('vorbis')
                ..u32le(0)
                ..u8(1)
                ..u32le(44100)
                ..u32le(0)
                ..u32le(160000)
                ..u32le(0)
                ..u8(0xB8)
                ..u8(1))
              .bytes;
      final comments = Uint8List.fromList([
        1, ...latin1.encode('vorbis'), // packet type 3 below
        ...vorbisComments({
          'COVERART': 'x' * 300,
          'REPLAYGAIN_TRACK_GAIN': '-3.50 dB',
        }),
      ])..[0] = 3;
      // Split the comment packet over two pages (255-byte lacing).
      final first = Uint8List.sublistView(comments, 0, 255);
      final rest = Uint8List.sublistView(comments, 255);
      final page2 =
          (Bytes()
                ..ascii('OggS')
                ..zeros(2)
                ..u64le(0)
                ..u32le(7)
                ..u32le(1)
                ..u32le(0)
                ..u8(1)
                ..u8(255)
                ..addAll(first))
              .bytes;
      final page3 =
          (Bytes()
                ..ascii('OggS')
                ..u8(0)
                ..u8(1)
                ..u64le(0)
                ..u32le(7)
                ..u32le(2)
                ..u32le(0)
                ..u8(1)
                ..u8(rest.length)
                ..addAll(rest))
              .bytes;
      final info = read(
        Uint8List.fromList([
          ...oggPage([id]),
          ...page2,
          ...page3,
        ]),
      );
      expect(info.codec, 'Vorbis');
      expect(info.sampleRate, 44100);
      expect(info.channels, 1);
      expect(info.bitrate, 160000); // nominal, no last granule
      expect(info.replayGain.trackGain, -3.5);
    });
  });

  test('WAV fmt chunk and an id3 chunk', () {
    final id3 = id3v23({'REPLAYGAIN_TRACK_GAIN': '-1.00 dB'});
    final fmt =
        (Bytes()
              ..u16le(1)
              ..u16le(2)
              ..u32le(48000)
              ..u32le(48000 * 6)
              ..u16le(6)
              ..u16le(24))
            .bytes;
    final body =
        (Bytes()
              ..ascii('WAVE')
              ..ascii('fmt ')
              ..u32le(fmt.length)
              ..addAll(fmt)
              ..ascii('data')
              ..u32le(6000)
              ..zeros(6000)
              ..ascii('id3 ')
              ..u32le(id3.length)
              ..addAll(id3)
              ..zeros(id3.length.isOdd ? 1 : 0))
            .bytes;
    final info = read(
      (Bytes()
            ..ascii('RIFF')
            ..u32le(body.length)
            ..addAll(body))
          .bytes,
    );
    expect(techBadge(info), 'PCM · 24-bit / 48 kHz');
    expect(info.bitrate, 48000 * 6 * 8);
    expect(info.replayGain.trackGain, -1.0);
  });

  test('a missing file is unreadable', () {
    expect(readAudioFileInfo('/no/such/file.flac'), AudioFileInfo.unreadable);
  });
}
