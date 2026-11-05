import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../tags/id3.dart';

/// One picture found in an audio file's tags.
class FoundPicture {
  const FoundPicture(this.bytes, {required this.type, this.mime = ''});

  final Uint8List bytes;

  /// ID3 / FLAC picture type: 3 front cover, 0 other, 4 back cover,
  /// 1-2 file icons, …
  final int type;
  final String mime;
}

/// The cover embedded in [path], or null when the file has none.
///
/// Throws a [FileSystemException] when the file can't be read at all (it
/// may be gone, still being written, or not accessible right now), so the
/// caller doesn't remember that as "no cover".
///
/// Reads with `audio_metadata_reader` first (MP3, FLAC, MP4, Ogg, …), then
/// with [scanTagPictures], which also understands ID3v2.2 and APEv2 tags.
Uint8List? readEmbeddedPicture(String path) {
  final file = File(path);
  // Fails with a FileSystemException when the file can't be opened.
  file.openSync().closeSync();
  var pictures = <FoundPicture>[];
  try {
    pictures = [
      for (final p in readMetadata(file, getImage: true).pictures)
        FoundPicture(
          p.bytes,
          // The enum follows the ID3 numbering (0 other, 3 front cover).
          type: p.pictureType.index,
          mime: p.mimetype,
        ),
    ];
  } on Object {
    // An unsupported or unusual layout: the scan below may still find it.
  }
  if (choosePicture(pictures) == null) {
    pictures = scanTagPictures(_readTags(file));
  }
  return choosePicture(pictures)?.bytes;
}

/// The picture to show as the cover: the front cover, else "other", else
/// any other picture except file icons and links.
FoundPicture? choosePicture(List<FoundPicture> pictures) {
  final usable = [
    for (final p in pictures)
      // "-->" is an ID3 link to a picture elsewhere, not image data.
      if (p.mime != '-->' && looksLikeImage(p.bytes)) p,
  ];
  for (final wanted in [3, 0]) {
    for (final p in usable) {
      if (p.type == wanted) return p;
    }
  }
  for (final p in usable) {
    if (p.type != 1 && p.type != 2) return p;
  }
  return usable.isEmpty ? null : usable.first;
}

/// Whether [bytes] start like a JPEG, PNG, GIF, BMP or WebP image.
///
/// Also catches pictures still in ID3's "unsynchronised" form, which
/// `audio_metadata_reader` returns as they are: such a JPEG starts
/// FF D8 FF 00, a byte no real JPEG has there.
bool looksLikeImage(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) {
    if (bytes.length < at + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[at + i] != magic[i]) return false;
    }
    return true;
  }

  if (bytes.length < 16) return false;
  return (starts([0xFF, 0xD8, 0xFF]) && bytes[3] >= 0xC0) ||
      starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) ||
      starts(ascii.encode('GIF8')) ||
      starts(ascii.encode('BM')) ||
      (starts(ascii.encode('RIFF')) && starts(ascii.encode('WEBP'), 8));
}

/// The parts of [file] where tags live: the start (ID3v2) and the last
/// 64 KiB (APEv2, ID3v2 with a footer), read without loading the audio.
Uint8List _readTags(File file) {
  final raf = file.openSync();
  try {
    final length = raf.lengthSync();
    final head = raf.readSync(10);
    var headLength = 10;
    if (head.length == 10 && isId3v2Header(head, 0)) {
      headLength = id3v2TagLength(head, 0) + 10;
    }
    raf.setPositionSync(0);
    final start = raf.readSync(headLength.clamp(0, length));
    const tailLength = 64 * 1024;
    if (length <= start.length + tailLength) {
      raf.setPositionSync(start.length);
      return Uint8List.fromList([...start, ...raf.readSync(length)]);
    }
    raf.setPositionSync(length - tailLength);
    // A gap marker keeps the two parts from running into each other.
    return Uint8List.fromList([
      ...start,
      ...List.filled(16, 0),
      ...raf.readSync(tailLength),
    ]);
  } finally {
    raf.closeSync();
  }
}

/// Pictures in every ID3v2 (2.2, 2.3, 2.4) and APEv2 tag found in [bytes].
/// Damaged tags are skipped, never thrown on.
List<FoundPicture> scanTagPictures(Uint8List bytes) {
  final found = <FoundPicture>[];
  for (
    var i = bytes.indexOf(0x49);
    i >= 0 && i + 10 <= bytes.length;
    i = _next(bytes, 0x49, i + 1)
  ) {
    if (isId3v2Header(bytes, i)) {
      try {
        found.addAll(_id3Pictures(bytes, i));
      } on Object {
        // A damaged tag: keep looking.
      }
    }
  }
  final ape = _indexOf(bytes, ascii.encode('APETAGEX'));
  if (ape >= 0) {
    try {
      found.addAll(_apePictures(bytes, ape));
    } on Object {
      // Ditto.
    }
  }
  return found;
}

int _next(Uint8List bytes, int value, int from) {
  for (var i = from; i < bytes.length; i++) {
    if (bytes[i] == value) return i;
  }
  return -1;
}

List<FoundPicture> _id3Pictures(Uint8List bytes, int start) => [
  for (final frame in id3v2Frames(bytes, start))
    if (frame.id == 'APIC' || frame.id == 'PIC')
      ?_pictureFrame(frame.data, legacy: frame.id == 'PIC'),
];

/// An APIC (or ID3v2.2 PIC) frame body.
FoundPicture? _pictureFrame(List<int> data, {required bool legacy}) {
  if (data.length < 4) return null;
  final encoding = data[0];
  var i = 1;
  final String mime;
  if (legacy) {
    final format = ascii.decode(data.sublist(1, 4), allowInvalid: true);
    mime = switch (format.toUpperCase()) {
      'PNG' => 'image/png',
      '-->' => '-->',
      _ => 'image/jpeg',
    };
    i = 4;
  } else {
    final zero = data.indexOf(0, 1);
    if (zero < 0) return null;
    mime = latin1.decode(data.sublist(1, zero), allowInvalid: true);
    i = zero + 1;
  }
  if (i >= data.length) return null;
  final type = data[i++];
  // The description ends with one zero byte, or two in UTF-16.
  final wide = encoding == 1 || encoding == 2;
  while (i < data.length) {
    if (wide) {
      if (i + 1 < data.length && data[i] == 0 && data[i + 1] == 0) {
        i += 2;
        break;
      }
      i += 2;
    } else {
      if (data[i++] == 0) break;
    }
  }
  if (i >= data.length) return null;
  return FoundPicture(
    Uint8List.fromList(data.sublist(i)),
    type: type,
    mime: mime,
  );
}

/// APEv2 items "Cover Art (Front)" and the like: `name\0image-bytes`.
List<FoundPicture> _apePictures(Uint8List bytes, int at) {
  // Header and footer look alike; the footer is the one at the end.
  var footer = at;
  for (
    var k = _indexOf(bytes, ascii.encode('APETAGEX'), at + 1);
    k >= 0;
    k = _indexOf(bytes, ascii.encode('APETAGEX'), k + 1)
  ) {
    footer = k;
  }
  final tagSize = _le(bytes, footer + 12);
  final count = _le(bytes, footer + 16);
  final flags = _le(bytes, footer + 20);
  // In a footer, the size counts the items and the footer itself.
  final isHeader = flags & 0x20000000 != 0;
  var i = isHeader ? footer + 32 : footer + 32 - tagSize;
  if (i < 0) return const [];
  final pictures = <FoundPicture>[];
  for (var n = 0; n < count && i + 8 < bytes.length; n++) {
    final valueSize = _le(bytes, i);
    final itemFlags = _le(bytes, i + 4);
    final keyEnd = bytes.indexOf(0, i + 8);
    if (keyEnd < 0) break;
    final key = ascii.decode(bytes.sublist(i + 8, keyEnd), allowInvalid: true);
    final valueStart = keyEnd + 1;
    final valueEnd = valueStart + valueSize;
    if (valueEnd > bytes.length) break;
    // Binary items (type 1) whose key names cover art.
    if ((itemFlags >> 1) & 3 == 1 &&
        key.toLowerCase().startsWith('cover art')) {
      final value = bytes.sublist(valueStart, valueEnd);
      final name = value.indexOf(0);
      final image = Uint8List.fromList(value.sublist(name + 1));
      final type = key.toLowerCase().contains('front') ? 3 : 0;
      pictures.add(FoundPicture(image, type: type));
    }
    i = valueEnd;
  }
  return pictures;
}

int _le(List<int> b, int i) =>
    b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

int _indexOf(Uint8List bytes, List<int> pattern, [int from = 0]) {
  outer:
  for (var i = from; i + pattern.length <= bytes.length; i++) {
    for (var k = 0; k < pattern.length; k++) {
      if (bytes[i + k] != pattern[k]) continue outer;
    }
    return i;
  }
  return -1;
}
