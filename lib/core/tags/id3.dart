import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A small, forgiving ID3 reader: frames of ID3v2.2/2.3/2.4 tags (with
/// unsynchronisation and extended headers) and the ID3v1 fields. Used where
/// `audio_metadata_reader` decodes text or pictures wrongly or not at all.

/// One ID3v2 frame: its ID ("TIT2", or "TT2" in ID3v2.2) and its data, with
/// unsynchronisation undone.
class Id3Frame {
  const Id3Frame(this.id, this.data, this.version);

  final String id;
  final Uint8List data;

  /// The tag's major version: 2, 3 or 4.
  final int version;
}

/// Whether an ID3v2 header starts at [i].
bool isId3v2Header(List<int> b, int i) =>
    i + 10 <= b.length &&
    b[i] == 0x49 &&
    b[i + 1] == 0x44 &&
    b[i + 2] == 0x33 && // "ID3"
    b[i + 3] >= 2 &&
    b[i + 3] <= 4 &&
    b[i + 4] != 0xFF &&
    (b[i + 6] | b[i + 7] | b[i + 8] | b[i + 9]) < 0x80;

/// The size of the ID3v2 tag at [i], header included (0 if there is none).
int id3v2TagLength(List<int> b, int i) =>
    isId3v2Header(b, i) ? 10 + syncsafe(b, i + 6) : 0;

int syncsafe(List<int> b, int i) =>
    (b[i] << 21) | (b[i + 1] << 14) | (b[i + 2] << 7) | b[i + 3];

int _be(List<int> b, int i, int n) {
  var v = 0;
  for (var k = 0; k < n; k++) {
    v = (v << 8) | b[i + k];
  }
  return v;
}

/// Undoes ID3 unsynchronisation (a zero inserted after each 0xFF).
Uint8List deunsynchronise(List<int> data) {
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < data.length; i++) {
    out.addByte(data[i]);
    if (data[i] == 0xFF && i + 1 < data.length && data[i + 1] == 0) i++;
  }
  return out.toBytes();
}

/// The frames of the ID3v2 tag starting at [start] in [bytes]. Stops
/// quietly at padding or at the first damaged frame.
List<Id3Frame> id3v2Frames(Uint8List bytes, int start) {
  if (!isId3v2Header(bytes, start)) return const [];
  final version = bytes[start + 3];
  final flags = bytes[start + 5];
  final end = (start + id3v2TagLength(bytes, start)).clamp(0, bytes.length);
  List<int> body = Uint8List.sublistView(bytes, start + 10, end);
  // Tag-wide unsynchronisation (2.2, 2.3; 2.4 marks it per frame).
  final unsync = flags & 0x80 != 0;
  if (unsync && version < 4) body = deunsynchronise(body);
  var i = 0;
  if (version >= 3 && flags & 0x40 != 0 && body.length >= 4) {
    // Extended header.
    i = version == 4 ? syncsafe(body, 0) : _be(body, 0, 4) + 4;
  }
  final idLength = version == 2 ? 3 : 4;
  final headerLength = version == 2 ? 6 : 10;
  final frames = <Id3Frame>[];
  while (i + headerLength <= body.length) {
    if (body[i] == 0) break; // padding
    final id = ascii.decode(body.sublist(i, i + idLength), allowInvalid: true);
    final size = switch (version) {
      2 => _be(body, i + 3, 3),
      3 => _be(body, i + 4, 4),
      _ => syncsafe(body, i + 4),
    };
    final frameFlags = version == 2 ? 0 : _be(body, i + 8, 2);
    final dataStart = i + headerLength;
    final dataEnd = dataStart + size;
    if (size <= 0 || dataEnd > body.length) break;
    var data = Uint8List.fromList(body.sublist(dataStart, dataEnd));
    if (version == 4 && (frameFlags & 0x0002 != 0 || unsync)) {
      data = deunsynchronise(data);
    }
    // 2.4: a data length indicator comes first when flagged.
    if (version == 4 && frameFlags & 0x0001 != 0 && data.length >= 4) {
      data = Uint8List.sublistView(data, 4);
    }
    frames.add(Id3Frame(id, data, version));
    i = dataEnd;
  }
  return frames;
}

/// Decodes ID3 text [raw] in [encoding]: 0 ISO-8859-1, 1 UTF-16 with a BOM
/// (or without one, as some taggers write it), 2 UTF-16BE, 3 UTF-8. Every
/// null-separated value, trimmed, empty ones dropped.
///
/// ISO-8859-1 text is kept as such even when it is really Shift-JIS or
/// UTF-8: the platform repairs that later (`TextRepair.kt`), with the
/// tables Dart lacks.
List<String> decodeId3Text(int encoding, List<int> raw) {
  final String text;
  switch (encoding) {
    case 1 || 2:
      text = _utf16(raw, bigEndian: encoding == 2);
    case 3:
      text = utf8.decode(raw, allowMalformed: true);
    default:
      text = latin1.decode(raw);
  }
  return [
    for (final value in text.split('\u0000'))
      if (value.trim().isNotEmpty) value.trim(),
  ];
}

String _utf16(List<int> raw, {required bool bigEndian}) {
  var bytes = raw;
  bool? be;
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) be = false;
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) be = true;
    if (be != null) bytes = bytes.sublist(2);
  }
  // UTF-16BE (encoding 2) has no BOM by definition; "UTF-16" without one
  // is read in whichever byte order gives the more plausible text.
  if (be == null && bigEndian) be = true;
  if (be == null) {
    final le = _units(bytes, bigEndian: false);
    final beText = _units(bytes, bigEndian: true);
    return textPlausibility(beText) > textPlausibility(le) ? beText : le;
  }
  return _units(bytes, bigEndian: be);
}

String _units(List<int> bytes, {required bool bigEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(
      bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : bytes[i] | (bytes[i + 1] << 8),
    );
  }
  // Values are separated by U+0000, which String keeps.
  return String.fromCharCodes(units);
}

/// How much [text] looks like real text: letters of common scripts and
/// ASCII count for it; controls, private use and unpaired surrogates
/// against it.
int textPlausibility(String text) {
  var score = 0;
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u == 0) continue;
    if (u >= 0x20 && u < 0x7F) {
      score += 2;
    } else if (u < 0x20 || (u >= 0x7F && u < 0xA0)) {
      score -= 4;
    } else if (u >= 0xD800 && u < 0xDC00) {
      final paired =
          i + 1 < units.length &&
          units[i + 1] >= 0xDC00 &&
          units[i + 1] < 0xE000;
      score += paired ? 1 : -4;
      if (paired) i++;
    } else if (u >= 0xDC00 && u < 0xE000) {
      score -= 4;
    } else if (u >= 0xE000 && u < 0xF900) {
      score -= 3;
    } else if ((u >= 0x3040 && u < 0x3100) || // kana
        (u >= 0x4E00 && u < 0xA000) || // Han
        (u >= 0xAC00 && u < 0xD7A4) || // Hangul
        (u >= 0xA0 && u < 0x250) || // Latin
        (u >= 0x370 && u < 0x530) || // Greek, Cyrillic
        (u >= 0x3000 && u < 0x3040) ||
        (u >= 0xFF00 && u < 0xFFF0)) {
      score += 1;
    } else {
      score -= 1;
    }
  }
  return score;
}

/// Title, artist, album and album artist from a file's ID3 tags: ID3v2
/// where present, else ID3v1.
class Id3Text {
  const Id3Text({this.title, this.artist, this.album, this.albumArtist});

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;

  bool get isEmpty =>
      title == null && artist == null && album == null && albumArtist == null;
}

/// Reads [Id3Text] from the start (ID3v2) and the last 128 bytes (ID3v1)
/// of [path], without loading the audio. Null when the file has no ID3
/// tag. Throws a [FileSystemException] when the file can't be read.
Id3Text? readId3Text(String path) {
  final raf = File(path).openSync();
  try {
    final length = raf.lengthSync();
    final head = raf.readSync(10);
    Id3Text? v2;
    final tagLength = id3v2TagLength(head, 0);
    if (tagLength > 0) {
      raf.setPositionSync(0);
      v2 = id3v2TextOf(raf.readSync(tagLength.clamp(0, length)));
    }
    Id3Text? v1;
    if (length >= 128) {
      raf.setPositionSync(length - 128);
      v1 = id3v1TextOf(raf.readSync(128));
    }
    if (v2 == null && v1 == null) return null;
    return Id3Text(
      title: v2?.title ?? v1?.title,
      artist: v2?.artist ?? v1?.artist,
      album: v2?.album ?? v1?.album,
      albumArtist: v2?.albumArtist,
    );
  } finally {
    raf.closeSync();
  }
}

/// The text fields of the ID3v2 tag at the start of [bytes].
Id3Text? id3v2TextOf(Uint8List bytes) {
  String? title, artist, album, albumArtist;
  for (final frame in id3v2Frames(bytes, 0)) {
    if (frame.data.isEmpty) continue;
    List<String> values() =>
        decodeId3Text(frame.data[0], Uint8List.sublistView(frame.data, 1));
    switch (frame.id) {
      case 'TIT2' || 'TT2':
        title ??= values().firstOrNull;
      case 'TPE1' || 'TP1':
        final v = values();
        if (v.isNotEmpty) artist ??= v.join(', ');
      case 'TALB' || 'TAL':
        album ??= values().firstOrNull;
      case 'TPE2' || 'TP2':
        final v = values();
        if (v.isNotEmpty) albumArtist ??= v.join(', ');
    }
  }
  final text = Id3Text(
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
  );
  return text.isEmpty ? null : text;
}

/// The ID3v1 fields of [last128] (the file's last 128 bytes), as
/// ISO-8859-1 like the standard says; Shift-JIS and UTF-8 written there
/// anyway are repaired later on the platform.
Id3Text? id3v1TextOf(List<int> last128) {
  if (last128.length != 128 ||
      last128[0] != 0x54 ||
      last128[1] != 0x41 ||
      last128[2] != 0x47) {
    return null; // "TAG"
  }
  String? field(int from) {
    var raw = last128.sublist(from, from + 30);
    final zero = raw.indexOf(0);
    if (zero >= 0) raw = raw.sublist(0, zero);
    final text = latin1.decode(raw).trim();
    return text.isEmpty ? null : text;
  }

  final text = Id3Text(title: field(3), artist: field(33), album: field(63));
  return text.isEmpty ? null : text;
}
