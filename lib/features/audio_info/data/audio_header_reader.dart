import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/audio_info.dart';

/// Random access to a file's bytes (a file on the phone, or memory in
/// tests). Reads past the end return fewer bytes.
abstract interface class ByteSource {
  int get length;
  Uint8List read(int offset, int count);
}

class MemoryByteSource implements ByteSource {
  MemoryByteSource(this.bytes);

  final Uint8List bytes;

  @override
  int get length => bytes.length;

  @override
  Uint8List read(int offset, int count) {
    final start = offset.clamp(0, bytes.length);
    return Uint8List.sublistView(
      bytes,
      start,
      math.min(bytes.length, start + math.max(count, 0)),
    );
  }
}

class _FileByteSource implements ByteSource {
  _FileByteSource(this._file) : length = _file.lengthSync();

  final RandomAccessFile _file;

  @override
  final int length;

  @override
  Uint8List read(int offset, int count) {
    if (offset >= length || count <= 0) return Uint8List(0);
    _file.setPositionSync(offset);
    return _file.readSync(math.min(count, length - offset));
  }
}

/// Reads [path]'s header. Synchronous (run it in an isolate) and never
/// throws: unreadable or unknown files give [AudioFileInfo.unreadable].
AudioFileInfo readAudioFileInfo(String path) {
  RandomAccessFile? file;
  try {
    file = File(path).openSync();
    return readAudioInfo(_FileByteSource(file));
  } on Object {
    return AudioFileInfo.unreadable;
  } finally {
    try {
      file?.closeSync();
    } on Object {
      // Already closed.
    }
  }
}

/// Our own parsers for the formats Android plays: FLAC, Ogg (Vorbis, Opus,
/// FLAC), MP3, MP4 (AAC, ALAC) and WAV. Reads only headers and tags.
AudioFileInfo readAudioInfo(ByteSource source) {
  try {
    final head = source.read(0, 12);
    if (_ascii(head, 0, 4) == 'fLaC') return _Flac(source).read(0);
    if (_ascii(head, 0, 4) == 'OggS') return _Ogg(source).read();
    if (_ascii(head, 4, 4) == 'ftyp') return _Mp4(source).read();
    if (_ascii(head, 0, 4) == 'RIFF' && _ascii(head, 8, 4) == 'WAVE') {
      return _Wav(source).read();
    }
    // MP3, or FLAC with a leading ID3 tag.
    var offset = 0;
    var tags = const <String, String>{};
    if (_ascii(head, 0, 3) == 'ID3') {
      final id3 = readId3v2(source, 0);
      tags = id3.tags;
      offset = id3.end;
    }
    if (_ascii(source.read(offset, 4), 0, 4) == 'fLaC') {
      return _Flac(source).read(offset);
    }
    final ape = readApeTags(source);
    final info = _Mp3(source).read(offset);
    if (info == null) return AudioFileInfo.unreadable;
    return info.copyWith(replayGain: replayGainFromTags({...ape, ...tags}));
  } on Object {
    return AudioFileInfo.unreadable;
  }
}

/// ReplayGain from tags keyed by upper-case names (Vorbis comments, ID3
/// TXXX descriptions, APE and MP4 freeform names). Opus's R128 tags are
/// relative to −23 LUFS, ReplayGain's to −18 LUFS: 5 dB apart.
ReplayGain replayGainFromTags(Map<String, String> tags) {
  double? r128(String key) {
    final value = int.tryParse(tags[key]?.trim() ?? '');
    return value == null ? null : value / 256 + 5;
  }

  return ReplayGain(
    trackGain:
        parseGain(tags['REPLAYGAIN_TRACK_GAIN']) ?? r128('R128_TRACK_GAIN'),
    trackPeak: parsePeak(tags['REPLAYGAIN_TRACK_PEAK']),
    albumGain:
        parseGain(tags['REPLAYGAIN_ALBUM_GAIN']) ?? r128('R128_ALBUM_GAIN'),
    albumPeak: parsePeak(tags['REPLAYGAIN_ALBUM_PEAK']),
  );
}

// ---------------------------------------------------------------- helpers

String _ascii(Uint8List bytes, int offset, int count) =>
    offset + count > bytes.length
    ? ''
    : String.fromCharCodes(bytes, offset, offset + count);

int _u16be(Uint8List b, int o) => b[o] << 8 | b[o + 1];
int _u24be(Uint8List b, int o) => b[o] << 16 | b[o + 1] << 8 | b[o + 2];
int _u32be(Uint8List b, int o) =>
    b[o] << 24 | b[o + 1] << 16 | b[o + 2] << 8 | b[o + 3];
int _u16le(Uint8List b, int o) => b[o] | b[o + 1] << 8;
int _u32le(Uint8List b, int o) =>
    b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24;
int _u64be(Uint8List b, int o) => _u32be(b, o) * 0x100000000 + _u32be(b, o + 4);
int _u64le(Uint8List b, int o) => _u32le(b, o) + _u32le(b, o + 4) * 0x100000000;

String _utf8(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);

/// Average bitrate from a byte count and a play time, or null.
int? _bitrate(int bytes, double seconds) =>
    seconds > 0.5 && bytes > 0 ? (bytes * 8 / seconds).round() : null;

/// Vorbis comments ("KEY=value" pairs after a vendor string), shared by
/// FLAC, Vorbis and Opus. Keys come back upper-case.
Map<String, String> parseVorbisComments(Uint8List b, int offset) {
  final tags = <String, String>{};
  var o = offset;
  if (o + 4 > b.length) return tags;
  o += 4 + _u32le(b, o); // vendor
  if (o + 4 > b.length) return tags;
  final count = _u32le(b, o);
  o += 4;
  for (var i = 0; i < count && o + 4 <= b.length; i++) {
    final length = _u32le(b, o);
    o += 4;
    if (o + length > b.length) break;
    final text = _utf8(Uint8List.sublistView(b, o, o + length));
    o += length;
    final eq = text.indexOf('=');
    if (eq > 0) {
      tags[text.substring(0, eq).toUpperCase()] = text.substring(eq + 1);
    }
  }
  return tags;
}

// ------------------------------------------------------------------- FLAC

class _Flac {
  _Flac(this.source);

  final ByteSource source;

  /// Most metadata blocks are small; pictures are skipped without reading.
  static const _maxBlock = 1 << 20;

  AudioFileInfo read(int start) {
    var o = start + 4;
    AudioFileInfo? info;
    var tags = const <String, String>{};
    var totalSamples = 0;
    for (var i = 0; i < 128; i++) {
      final header = source.read(o, 4);
      if (header.length < 4) break;
      final last = header[0] & 0x80 != 0;
      final type = header[0] & 0x7F;
      final length = _u24be(header, 1);
      if (type == 0 && length >= 18) {
        final s = source.read(o + 4, 18);
        final rate = s[10] << 12 | s[11] << 4 | s[12] >> 4;
        final channels = (s[12] >> 1 & 0x07) + 1;
        final bits = ((s[12] & 0x01) << 4 | s[13] >> 4) + 1;
        totalSamples = (s[13] & 0x0F) * 0x100000000 + _u32be(s, 14);
        info = AudioFileInfo(
          codec: 'FLAC',
          sampleRate: rate,
          bitDepth: bits,
          channels: channels,
        );
      } else if (type == 4 && length <= _maxBlock) {
        tags = parseVorbisComments(source.read(o + 4, length), 0);
      }
      o += 4 + length;
      if (last) break;
    }
    if (info == null) return AudioFileInfo.unreadable;
    final rate = info.sampleRate ?? 0;
    return info.copyWith(
      bitrate: rate > 0
          ? _bitrate(source.length - o, totalSamples / rate)
          : null,
      replayGain: replayGainFromTags(tags),
    );
  }
}

// -------------------------------------------------------------------- Ogg

class _Ogg {
  _Ogg(this.source);

  final ByteSource source;

  static const _maxPacket = 4 << 20;

  AudioFileInfo read() {
    final packets = _firstPackets(2);
    if (packets.isEmpty) return AudioFileInfo.unreadable;
    final id = packets[0].bytes;
    final serial = packets[0].serial;
    final comments = packets.length > 1 ? packets[1].bytes : Uint8List(0);
    final lastGranule = _lastGranule(serial);

    if (_ascii(id, 0, 7) == '\x01vorbis' && id.length >= 30) {
      final rate = _u32le(id, 12);
      final nominal = _u32le(id, 20);
      return AudioFileInfo(
        codec: 'Vorbis',
        sampleRate: rate,
        channels: id[11],
        bitrate: lastGranule != null && rate > 0
            ? _bitrate(source.length, lastGranule / rate)
            : (nominal > 0 && nominal < 0x7FFFFFFF ? nominal : null),
        replayGain: _ascii(comments, 0, 7) == '\x03vorbis'
            ? replayGainFromTags(parseVorbisComments(comments, 7))
            : ReplayGain.none,
      );
    }
    if (_ascii(id, 0, 8) == 'OpusHead' && id.length >= 19) {
      final preSkip = _u16le(id, 10);
      return AudioFileInfo(
        codec: 'Opus',
        // Opus always decodes at 48 kHz.
        sampleRate: 48000,
        channels: id[9],
        bitrate: lastGranule != null
            ? _bitrate(source.length, (lastGranule - preSkip) / 48000)
            : null,
        replayGain: _ascii(comments, 0, 8) == 'OpusTags'
            ? replayGainFromTags(parseVorbisComments(comments, 8))
            : ReplayGain.none,
      );
    }
    if (_ascii(id, 0, 5) == '\x7fFLAC' && id.length >= 51) {
      // Mapping header, then "fLaC" and a STREAMINFO block.
      final s = Uint8List.sublistView(id, 17);
      final rate = s[10] << 12 | s[11] << 4 | s[12] >> 4;
      final tags = comments.length > 4
          ? parseVorbisComments(comments, 4)
          : const <String, String>{};
      return AudioFileInfo(
        codec: 'FLAC',
        sampleRate: rate,
        channels: (s[12] >> 1 & 0x07) + 1,
        bitDepth: ((s[12] & 0x01) << 4 | s[13] >> 4) + 1,
        bitrate: lastGranule != null && rate > 0
            ? _bitrate(source.length, lastGranule / rate)
            : null,
        replayGain: replayGainFromTags(tags),
      );
    }
    return AudioFileInfo.unreadable;
  }

  /// The first [count] packets of the first logical stream.
  List<({Uint8List bytes, int serial})> _firstPackets(int count) {
    final packets = <({Uint8List bytes, int serial})>[];
    final current = BytesBuilder(copy: false);
    int? serial;
    var o = 0;
    for (var page = 0; page < 512 && packets.length < count; page++) {
      final header = source.read(o, 27);
      if (_ascii(header, 0, 4) != 'OggS') break;
      final segments = header[26];
      final table = source.read(o + 27, segments);
      if (table.length < segments) break;
      final pageSerial = _u32le(header, 14);
      var data = o + 27 + segments;
      final pageLength = table.fold(0, (sum, s) => sum + s);
      if (serial != null && pageSerial != serial) {
        o = data + pageLength;
        continue;
      }
      serial = pageSerial;
      final body = source.read(data, pageLength);
      var at = 0;
      for (final segment in table) {
        if (current.length + segment <= _maxPacket) {
          current.add(Uint8List.sublistView(body, at, at + segment));
        }
        at += segment;
        if (segment < 255) {
          packets.add((bytes: current.takeBytes(), serial: pageSerial));
          if (packets.length == count) break;
        }
      }
      data += pageLength;
      o = data;
    }
    return packets;
  }

  /// The granule position (samples) of the stream's last page.
  int? _lastGranule(int serial) {
    const window = 64 * 1024;
    final start = math.max(0, source.length - window);
    final tail = source.read(start, window);
    for (var i = tail.length - 27; i >= 0; i--) {
      if (tail[i] == 0x4F &&
          _ascii(tail, i, 4) == 'OggS' &&
          _u32le(tail, i + 14) == serial) {
        final granule = _u64le(tail, i + 6);
        // −1 (all bits set) means "no packet ends on this page".
        if (granule > 0) return granule;
      }
    }
    return null;
  }
}

// -------------------------------------------------------------------- ID3

/// An ID3v2 tag's TXXX values (by upper-case description) and where the
/// audio after it starts.
({Map<String, String> tags, int end}) readId3v2(ByteSource source, int at) {
  final header = source.read(at, 10);
  if (_ascii(header, 0, 3) != 'ID3' || header.length < 10) {
    return (tags: const {}, end: at);
  }
  final version = header[3];
  final flags = header[5];
  final size =
      (header[6] & 0x7F) << 21 |
      (header[7] & 0x7F) << 14 |
      (header[8] & 0x7F) << 7 |
      (header[9] & 0x7F);
  final end = at + 10 + size + (flags & 0x10 != 0 ? 10 : 0);
  // Tags are mostly cover art; ReplayGain sits in the first few frames,
  // but large ones are read whole only up to this size.
  var body = source.read(at + 10, math.min(size, 16 << 20));
  if (version < 4 && flags & 0x80 != 0) body = _unsync(body);
  var o = 0;
  if (flags & 0x40 != 0 && body.length >= 4) {
    // Extended header.
    o += version >= 4
        ? ((body[0] & 0x7F) << 21 |
              (body[1] & 0x7F) << 14 |
              (body[2] & 0x7F) << 7 |
              (body[3] & 0x7F))
        : 4 + _u32be(body, 0);
  }
  final tags = <String, String>{};
  final idLength = version == 2 ? 3 : 4;
  final headerLength = version == 2 ? 6 : 10;
  while (o + headerLength <= body.length) {
    final id = _ascii(body, o, idLength);
    if (id.codeUnitAt(0) == 0) break; // padding
    final frameSize = switch (version) {
      2 => _u24be(body, o + 3),
      3 => _u32be(body, o + 4),
      _ =>
        (body[o + 4] & 0x7F) << 21 |
            (body[o + 5] & 0x7F) << 14 |
            (body[o + 6] & 0x7F) << 7 |
            (body[o + 7] & 0x7F),
    };
    final start = o + headerLength;
    if (frameSize <= 0 || start + frameSize > body.length) break;
    if (id == 'TXXX' || id == 'TXX') {
      var data = Uint8List.sublistView(body, start, start + frameSize);
      var usable = true;
      if (version == 3) {
        final frameFlags = body[o + 9];
        usable = frameFlags & 0xC0 == 0; // compressed or encrypted
        if (frameFlags & 0x20 != 0 && data.isNotEmpty) {
          data = Uint8List.sublistView(data, 1); // group ID
        }
      } else if (version >= 4) {
        final frameFlags = body[o + 9];
        usable = frameFlags & 0x0C == 0;
        if (frameFlags & 0x40 != 0 && data.isNotEmpty) {
          data = Uint8List.sublistView(data, 1);
        }
        if (frameFlags & 0x01 != 0 && data.length >= 4) {
          data = Uint8List.sublistView(data, 4); // data length
        }
        if (frameFlags & 0x02 != 0) data = _unsync(data);
      }
      if (usable) {
        if (_userText(data) case (final key, final value)) {
          tags[key.toUpperCase()] = value;
        }
      }
    }
    o = start + frameSize;
  }
  return (tags: tags, end: end);
}

/// Undoes ID3 unsynchronisation (FF 00 → FF).
Uint8List _unsync(Uint8List b) {
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < b.length; i++) {
    out.addByte(b[i]);
    if (b[i] == 0xFF && i + 1 < b.length && b[i + 1] == 0) i++;
  }
  return out.takeBytes();
}

/// A TXXX frame's (description, value).
(String, String)? _userText(Uint8List data) {
  if (data.isEmpty) return null;
  final encoding = data[0];
  final wide = encoding == 1 || encoding == 2;
  final text = Uint8List.sublistView(data, 1);
  // The description ends at the first terminator.
  var split = -1;
  if (wide) {
    for (var i = 0; i + 1 < text.length; i += 2) {
      if (text[i] == 0 && text[i + 1] == 0) {
        split = i;
        break;
      }
    }
  } else {
    split = text.indexOf(0);
  }
  if (split < 0) return null;
  String decode(Uint8List b) => switch (encoding) {
    0 => latin1.decode(b),
    3 => _utf8(b),
    _ => _utf16(b, bigEndian: encoding == 2),
  };
  final key = decode(Uint8List.sublistView(text, 0, split));
  final value = decode(Uint8List.sublistView(text, split + (wide ? 2 : 1)));
  return (key.trim(), value.replaceAll('\u0000', '').trim());
}

String _utf16(Uint8List b, {required bool bigEndian}) {
  var o = 0;
  var big = bigEndian;
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    big = false;
    o = 2;
  } else if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    big = true;
    o = 2;
  }
  final units = <int>[
    for (var i = o; i + 1 < b.length; i += 2)
      big ? b[i] << 8 | b[i + 1] : b[i] | b[i + 1] << 8,
  ];
  return String.fromCharCodes(units);
}

/// APEv2 items (upper-case keys) at the end of the file, before any ID3v1
/// tag. Some taggers store ReplayGain there for MP3.
Map<String, String> readApeTags(ByteSource source) {
  for (final footerAt in [source.length - 32, source.length - 128 - 32]) {
    if (footerAt < 0) continue;
    final footer = source.read(footerAt, 32);
    if (_ascii(footer, 0, 8) != 'APETAGEX') continue;
    final size = _u32le(footer, 12); // items + footer
    final count = _u32le(footer, 16);
    if (size < 32 || size > 16 << 20) return const {};
    final items = source.read(footerAt + 32 - size, size - 32);
    final tags = <String, String>{};
    var o = 0;
    for (var i = 0; i < count && o + 8 < items.length; i++) {
      final length = _u32le(items, o);
      final flags = _u32le(items, o + 4);
      final keyEnd = items.indexOf(0, o + 8);
      if (keyEnd < 0 || keyEnd + 1 + length > items.length) break;
      final key = _ascii(items, o + 8, keyEnd - o - 8);
      if (flags & 0x06 == 0) {
        // Text item.
        tags[key.toUpperCase()] = _utf8(
          Uint8List.sublistView(items, keyEnd + 1, keyEnd + 1 + length),
        );
      }
      o = keyEnd + 1 + length;
    }
    return tags;
  }
  return const {};
}

// -------------------------------------------------------------------- MP3

class _Mp3 {
  _Mp3(this.source);

  final ByteSource source;

  static const _bitratesV1 = {
    1: [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
    2: [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
    3: [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
  };
  static const _bitratesV2 = {
    1: [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
    2: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
    3: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
  };
  static const _rates = [44100, 48000, 32000];

  /// The first frame within this many bytes of the tag.
  static const _searchWindow = 128 * 1024;

  AudioFileInfo? read(int start) {
    final window = source.read(start, _searchWindow);
    for (var i = 0; i + 4 <= window.length; i++) {
      if (window[i] != 0xFF || window[i + 1] & 0xE0 != 0xE0) continue;
      final frame = _parse(window, i);
      if (frame == null) continue;
      // A real frame is followed by another one.
      final next = source.read(start + i + frame.length, 4);
      if (next.length == 4 && _parse(next, 0) == null) continue;
      return _describe(start + i, frame);
    }
    return null;
  }

  ({
    int version, // 1, 2 or 25 (2.5)
    int layer,
    int bitrate,
    int sampleRate,
    int channels,
    int length,
  })?
  _parse(Uint8List b, int o) {
    if (o + 4 > b.length) return null;
    final versionBits = b[o + 1] >> 3 & 0x03;
    final layerBits = b[o + 1] >> 1 & 0x03;
    final bitrateIndex = b[o + 2] >> 4;
    final rateIndex = b[o + 2] >> 2 & 0x03;
    if (versionBits == 1 || layerBits == 0) return null;
    if (bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) return null;
    final version = switch (versionBits) {
      3 => 1,
      2 => 2,
      _ => 25,
    };
    final layer = 4 - layerBits;
    final kbps = (version == 1
        ? _bitratesV1
        : _bitratesV2)[layer]![bitrateIndex];
    final rate =
        _rates[rateIndex] ~/
        (version == 1
            ? 1
            : version == 2
            ? 2
            : 4);
    final padding = b[o + 2] >> 1 & 0x01;
    final bps = kbps * 1000;
    final length = switch (layer) {
      1 => (12 * bps ~/ rate + padding) * 4,
      3 when version != 1 => 72 * bps ~/ rate + padding,
      _ => 144 * bps ~/ rate + padding,
    };
    if (length < 21) return null;
    return (
      version: version,
      layer: layer,
      bitrate: bps,
      sampleRate: rate,
      channels: b[o + 3] >> 6 == 3 ? 1 : 2,
      length: length,
    );
  }

  AudioFileInfo _describe(
    int at,
    ({
      int version,
      int layer,
      int bitrate,
      int sampleRate,
      int channels,
      int length,
    })
    frame,
  ) {
    final bytes = source.read(at, math.min(frame.length, 256));
    final samplesPerFrame = switch (frame.layer) {
      1 => 384,
      3 when frame.version != 1 => 576,
      _ => 1152,
    };
    // A Xing / Info (or VBRI) header gives the real average for VBR files.
    final sideInfo = frame.version == 1
        ? (frame.channels == 1 ? 17 : 32)
        : (frame.channels == 1 ? 9 : 17);
    int? frames;
    int? streamBytes;
    final xing = 4 + sideInfo;
    final tag = _ascii(bytes, xing, 4);
    if ((tag == 'Xing' || tag == 'Info') && bytes.length >= xing + 16) {
      final flags = _u32be(bytes, xing + 4);
      var o = xing + 8;
      if (flags & 1 != 0) {
        frames = _u32be(bytes, o);
        o += 4;
      }
      if (flags & 2 != 0) streamBytes = _u32be(bytes, o);
    } else if (_ascii(bytes, 36, 4) == 'VBRI' && bytes.length >= 54) {
      streamBytes = _u32be(bytes, 46);
      frames = _u32be(bytes, 50);
    }
    var bitrate = frame.bitrate;
    if (frames != null && frames > 0) {
      final seconds = frames * samplesPerFrame / frame.sampleRate;
      bitrate =
          _bitrate(streamBytes ?? (source.length - at), seconds) ?? bitrate;
    }
    return AudioFileInfo(
      codec: switch (frame.layer) {
        3 => 'MP3',
        2 => 'MP2',
        _ => 'MP1',
      },
      sampleRate: frame.sampleRate,
      channels: frame.channels,
      bitrate: bitrate,
    );
  }
}

// -------------------------------------------------------------------- MP4

class _Mp4 {
  _Mp4(this.source);

  final ByteSource source;

  /// The whole `moov` box is read when it's at most this large.
  static const _maxMoov = 32 << 20;

  AudioFileInfo read() {
    Uint8List? moov;
    var mdatBytes = 0;
    var o = 0;
    for (var i = 0; i < 1024 && o + 8 <= source.length; i++) {
      final header = source.read(o, 16);
      var size = _u32be(header, 0);
      final type = _ascii(header, 4, 4);
      var headerLength = 8;
      if (size == 1) {
        size = _u64be(header, 8);
        headerLength = 16;
      } else if (size == 0) {
        size = source.length - o;
      }
      if (size < headerLength) break;
      if (type == 'moov' && size <= _maxMoov) {
        moov = source.read(o + headerLength, size - headerLength);
      } else if (type == 'mdat') {
        mdatBytes += size - headerLength;
      }
      o += size;
    }
    if (moov == null) return AudioFileInfo.unreadable;

    AudioFileInfo? info;
    for (final trak in _children(moov, 0, moov.length, 'trak')) {
      final mdia = _child(moov, trak, 'mdia');
      if (mdia == null) continue;
      final hdlr = _child(moov, mdia, 'hdlr');
      if (hdlr == null || _ascii(moov, hdlr.start + 8, 4) != 'soun') continue;
      final mdhd = _child(moov, mdia, 'mdhd');
      var seconds = 0.0;
      if (mdhd != null) {
        final v1 = moov[mdhd.start] == 1;
        final timescale = _u32be(moov, mdhd.start + (v1 ? 20 : 12));
        final duration = v1
            ? _u64be(moov, mdhd.start + 24)
            : _u32be(moov, mdhd.start + 16);
        if (timescale > 0) seconds = duration / timescale;
      }
      final stbl = _path(moov, mdia, const ['minf', 'stbl']);
      final stsd = stbl == null ? null : _child(moov, stbl, 'stsd');
      if (stsd == null) continue;
      info = _sampleEntry(moov, stsd.start + 8, stsd.end, seconds, mdatBytes);
      if (info != null) break;
    }
    info ??= AudioFileInfo.unreadable;
    return info.copyWith(replayGain: replayGainFromTags(_freeformTags(moov)));
  }

  AudioFileInfo? _sampleEntry(
    Uint8List b,
    int o,
    int end,
    double seconds,
    int mdatBytes,
  ) {
    if (o + 36 > end) return null;
    final size = _u32be(b, o);
    final format = _ascii(b, o + 4, 4);
    final version = _u16be(b, o + 16);
    final channels = _u16be(b, o + 24);
    final sampleSize = _u16be(b, o + 26);
    final rate = _u32be(b, o + 32) >> 16;
    final childrenAt =
        o +
        36 +
        switch (version) {
          1 => 16,
          2 => 36,
          _ => 0,
        };
    final entryEnd = math.min(o + size, end);
    final computed = _bitrate(mdatBytes, seconds);
    switch (format) {
      case 'mp4a':
        final esds = _children(b, childrenAt, entryEnd, 'esds').firstOrNull;
        final config = esds == null ? null : _decoderConfig(b, esds);
        return AudioFileInfo(
          codec: switch (config?.objectType) {
            0x69 || 0x6B => 'MP3',
            _ => 'AAC',
          },
          sampleRate: rate,
          channels: channels,
          bitrate: computed ?? config?.avgBitrate,
        );
      case 'alac':
        final alac = _children(b, childrenAt, entryEnd, 'alac').firstOrNull;
        if (alac != null && alac.end - alac.start >= 28) {
          final c = alac.start + 4; // version and flags
          return AudioFileInfo(
            codec: 'ALAC',
            bitDepth: b[c + 5],
            channels: b[c + 9],
            sampleRate: _u32be(b, c + 20),
            bitrate: computed,
          );
        }
        return AudioFileInfo(
          codec: 'ALAC',
          bitDepth: sampleSize,
          channels: channels,
          sampleRate: rate,
          bitrate: computed,
        );
      case 'fLaC':
        return AudioFileInfo(
          codec: 'FLAC',
          bitDepth: sampleSize,
          channels: channels,
          sampleRate: rate,
          bitrate: computed,
        );
      case 'Opus':
        return AudioFileInfo(
          codec: 'Opus',
          channels: channels,
          sampleRate: 48000,
          bitrate: computed,
        );
      default:
        return null;
    }
  }

  /// The esds DecoderConfigDescriptor's object type and average bitrate.
  ({int objectType, int? avgBitrate})? _decoderConfig(
    Uint8List b,
    ({int start, int end}) esds,
  ) {
    var o = esds.start + 4; // version and flags
    (int tag, int length, int body)? descriptor(int at) {
      if (at >= esds.end) return null;
      final tag = b[at];
      var length = 0;
      var i = at + 1;
      for (var n = 0; n < 4 && i < esds.end; n++) {
        final byte = b[i++];
        length = length << 7 | byte & 0x7F;
        if (byte & 0x80 == 0) break;
      }
      return (tag, length, i);
    }

    final es = descriptor(o);
    if (es == null || es.$1 != 3) return null;
    o = es.$3 + 2; // ES_ID
    final flags = b[o++];
    if (flags & 0x80 != 0) o += 2;
    if (flags & 0x40 != 0) o += 1 + b[o];
    if (flags & 0x20 != 0) o += 2;
    final config = descriptor(o);
    if (config == null || config.$1 != 4 || config.$3 + 13 > esds.end) {
      return null;
    }
    final avg = _u32be(b, config.$3 + 9);
    return (objectType: b[config.$3], avgBitrate: avg > 0 ? avg : null);
  }

  /// moov/udta/meta/ilst freeform ("----") items by upper-case name.
  Map<String, String> _freeformTags(Uint8List moov) {
    final udta = _children(moov, 0, moov.length, 'udta').firstOrNull;
    final meta = udta == null ? null : _child(moov, udta, 'meta');
    if (meta == null) return const {};
    // `meta` is a full box in MP4 files, a plain one in QuickTime files.
    final metaStart = _ascii(moov, meta.start + 4, 4) == 'hdlr'
        ? meta.start
        : meta.start + 4;
    final ilst = _children(moov, metaStart, meta.end, 'ilst').firstOrNull;
    if (ilst == null) return const {};
    final tags = <String, String>{};
    for (final item in _children(moov, ilst.start, ilst.end, '----')) {
      String? name;
      String? value;
      for (final (type, box) in _all(moov, item.start, item.end)) {
        if (type == 'name' && box.end - box.start > 4) {
          name = _utf8(Uint8List.sublistView(moov, box.start + 4, box.end));
        } else if (type == 'data' && box.end - box.start > 8) {
          value = _utf8(Uint8List.sublistView(moov, box.start + 8, box.end));
        }
      }
      if (name != null && value != null) tags[name.toUpperCase()] = value;
    }
    return tags;
  }

  /// Boxes between [start] and [end] as (type, body range).
  Iterable<(String, ({int start, int end}))> _all(
    Uint8List b,
    int start,
    int end,
  ) sync* {
    var o = start;
    while (o + 8 <= end) {
      var size = _u32be(b, o);
      var header = 8;
      if (size == 1 && o + 16 <= end) {
        size = _u64be(b, o + 8);
        header = 16;
      } else if (size == 0) {
        size = end - o;
      }
      if (size < header || o + size > end) return;
      yield (_ascii(b, o + 4, 4), (start: o + header, end: o + size));
      o += size;
    }
  }

  Iterable<({int start, int end})> _children(
    Uint8List b,
    int start,
    int end,
    String type,
  ) => _all(b, start, end).where((e) => e.$1 == type).map((e) => e.$2);

  ({int start, int end})? _child(
    Uint8List b,
    ({int start, int end}) parent,
    String type,
  ) => _children(b, parent.start, parent.end, type).firstOrNull;

  ({int start, int end})? _path(
    Uint8List b,
    ({int start, int end}) parent,
    List<String> types,
  ) {
    ({int start, int end})? box = parent;
    for (final type in types) {
      if (box == null) return null;
      box = _child(b, box, type);
    }
    return box;
  }
}

// -------------------------------------------------------------------- WAV

class _Wav {
  _Wav(this.source);

  final ByteSource source;

  AudioFileInfo read() {
    var o = 12;
    AudioFileInfo? info;
    var tags = const <String, String>{};
    for (var i = 0; i < 256 && o + 8 <= source.length; i++) {
      final header = source.read(o, 8);
      final id = _ascii(header, 0, 4);
      final size = _u32le(header, 4);
      if (id == 'fmt ' && size >= 16) {
        final f = source.read(o + 8, math.min(size, 40));
        var tag = _u16le(f, 0);
        if (tag == 0xFFFE && f.length >= 26) tag = _u16le(f, 24);
        info = AudioFileInfo(
          codec: switch (tag) {
            1 || 3 => 'PCM',
            0x55 => 'MP3',
            _ => null,
          },
          channels: _u16le(f, 2),
          sampleRate: _u32le(f, 4),
          bitrate: _u32le(f, 8) * 8,
          bitDepth: tag == 1 || tag == 3 ? _u16le(f, 14) : null,
        );
      } else if (id == 'id3 ' || id == 'ID3 ') {
        tags = readId3v2(source, o + 8).tags;
      }
      o += 8 + size + (size & 1);
    }
    return (info ?? AudioFileInfo.unreadable).copyWith(
      replayGain: replayGainFromTags(tags),
    );
  }
}
