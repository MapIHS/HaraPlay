import 'dart:convert';
import 'dart:typed_data';

/// Builders for small, valid MP3 files with ID3 tags, for testing how
/// embedded pictures are found. Everything is generated here.

/// A minimal JPEG header of [width]x[height] (SOI, APP0, SOF0); enough for
/// size checks, not for decoding.
Uint8List fakeJpeg(int width, int height, {int fill = 0}) =>
    Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, //
      0xFF, 0xC0, 0x00, 0x11, 0x08,
      height >> 8, height & 0xFF, width >> 8, width & 0xFF,
      0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ...List.filled(16, fill), 0xFF, 0xD9,
    ]);

/// The start of a PNG (signature and IHDR).
Uint8List fakePng(int width, int height) => Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52,
  ...(ByteData(8)
        ..setUint32(0, width)
        ..setUint32(4, height))
      .buffer
      .asUint8List(),
  8, 6, 0, 0, 0, 0, 0, 0, 0,
]);

/// One embedded picture.
class Id3Picture {
  const Id3Picture(
    this.bytes, {
    this.mime = 'image/jpeg',
    this.type = 3,
    this.description = '',
    this.utf16 = false,
  });

  final Uint8List bytes;
  final String mime;

  /// ID3 picture type: 3 front cover, 4 back cover, 0 other, 1 file icon.
  final int type;
  final String description;

  /// The description in UTF-16 with a BOM (text encoding 1).
  final bool utf16;
}

Uint8List _syncsafe(int n) => Uint8List.fromList([
  (n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F, //
]);

Uint8List _be32(int n) => (ByteData(4)..setUint32(0, n)).buffer.asUint8List();

Uint8List _text(String id, String value, int version) =>
    _frame(id, [0, ...latin1.encode(value)], version);

Uint8List _frame(
  String id,
  List<int> body,
  int version, {
  bool unsynchronised = false,
}) {
  // ID3v2.4 unsynchronises frame by frame (flag 0x0002), and the size
  // counts the stored bytes.
  if (version == 4 && unsynchronised) body = _unsynchronise(body);
  final size = version == 4 ? _syncsafe(body.length) : _be32(body.length);
  final flags = version == 4 && unsynchronised ? 0x02 : 0;
  return Uint8List.fromList([...ascii.encode(id), ...size, 0, flags, ...body]);
}

List<int> _pictureBody(Id3Picture p, int version) {
  final description = p.utf16
      ? [
          0xFF,
          0xFE,
          for (final c in p.description.codeUnits) ...[c & 0xFF, c >> 8],
          0,
          0,
        ]
      : [...latin1.encode(p.description), 0];
  if (version == 2) {
    // PIC: a three-letter image format instead of a MIME type.
    final format = p.mime.contains('png') ? 'PNG' : 'JPG';
    return [
      p.utf16 ? 1 : 0,
      ...ascii.encode(format),
      p.type,
      ...description,
      ...p.bytes,
    ];
  }
  return [
    p.utf16 ? 1 : 0,
    ...latin1.encode(p.mime),
    0,
    p.type,
    ...description,
    ...p.bytes,
  ];
}

/// ID3 unsynchronisation: a zero after every 0xFF that is followed by
/// 0xE0 or more, or by zero.
List<int> _unsynchronise(List<int> data) {
  final out = <int>[];
  for (var i = 0; i < data.length; i++) {
    out.add(data[i]);
    if (data[i] == 0xFF &&
        (i + 1 == data.length || data[i + 1] >= 0xE0 || data[i + 1] == 0)) {
      out.add(0);
    }
  }
  return out;
}

/// An MP3 file: an ID3v2.[version] tag with [pictures] (and a title, and
/// optionally an album), then [audio] (MPEG frames without tags) or a few
/// silent frames.
Uint8List mp3WithId3({
  int version = 3,
  List<Id3Picture> pictures = const [],
  String title = 'Fixture',
  String? album,
  bool unsynchronised = false,
  bool id3v1 = false,
  int padding = 64,
  List<int>? audio,
  List<RawTextFrame> textFrames = const [],
  Id3v1Fields? id3v1Fields,
}) {
  final frames = <int>[];
  if (version == 2) {
    List<int> f2(String id, List<int> body) => [
      ...ascii.encode(id),
      body.length >> 16,
      (body.length >> 8) & 0xFF,
      body.length & 0xFF,
      ...body,
    ];
    frames.addAll(f2('TT2', [0, ...latin1.encode(title)]));
    if (album != null) frames.addAll(f2('TAL', [0, ...latin1.encode(album)]));
    for (final p in pictures) {
      frames.addAll(f2('PIC', _pictureBody(p, 2)));
    }
  } else {
    if (!textFrames.any((f) => f.id == 'TIT2')) {
      frames.addAll(_text('TIT2', title, version));
    }
    if (album != null) frames.addAll(_text('TALB', album, version));
    for (final f in textFrames) {
      frames.addAll(_frame(f.id, [f.encoding, ...f.raw], version));
    }
    for (final p in pictures) {
      frames.addAll(
        _frame(
          'APIC',
          _pictureBody(p, version),
          version,
          unsynchronised: unsynchronised,
        ),
      );
    }
  }
  var body = [...frames, ...List.filled(padding, 0)];
  // ID3v2.2 and 2.3 unsynchronise the whole tag.
  if (unsynchronised && version < 4) body = _unsynchronise(body);
  final header = [
    ...ascii.encode('ID3'),
    version,
    0,
    unsynchronised ? 0x80 : 0,
    ..._syncsafe(body.length),
  ];
  return Uint8List.fromList([
    ...header,
    ...body,
    if (audio != null)
      ...audio
    else
      for (var i = 0; i < 8; i++) ..._silentFrame,
    if (id3v1Fields != null)
      ...id3v1Fields.bytes()
    else if (id3v1)
      ..._id3v1(title),
  ]);
}

/// MPEG-1 Layer III, 128 kbit/s, 44.1 kHz, no padding: 417 bytes.
final _silentFrame = [0xFF, 0xFB, 0x90, 0x64, ...List.filled(413, 0)];

List<int> _id3v1(String title) {
  final t = latin1.encode(title.padRight(30).substring(0, 30));
  return [...ascii.encode('TAG'), ...t, ...List.filled(125 - 30, 0)];
}

/// An APEv2 tag (footer only) with a "Cover Art (Front)" item, as some
/// taggers append to MP3 files.
List<int> apeCoverTag(Uint8List image) {
  List<int> le(int n) =>
      (ByteData(4)..setUint32(0, n, Endian.little)).buffer.asUint8List();
  final value = [...latin1.encode('cover.jpg'), 0, ...image];
  final item = [
    ...le(value.length),
    ...le(1 << 1), // binary item
    ...ascii.encode('Cover Art (Front)'), 0,
    ...value,
  ];
  return [
    ...item,
    ...ascii.encode('APETAGEX'),
    ...le(2000),
    ...le(item.length + 32),
    ...le(1),
    ...le(0), // footer, no header
    ...List.filled(8, 0),
  ];
}

/// [mp3] with [tag] appended (before an ID3v1 tag, if any, is not
/// handled: append APE tags to files built without one).
Uint8List withTrailer(Uint8List mp3, List<int> tag) =>
    Uint8List.fromList([...mp3, ...tag]);

/// An ID3v2 text frame with an explicit encoding byte (0 Latin-1,
/// 1 UTF-16 with BOM, 2 UTF-16BE, 3 UTF-8) and raw text bytes, so tests can
/// write what real taggers write, including what they get wrong.
class RawTextFrame {
  const RawTextFrame(this.id, this.encoding, this.raw);

  final String id;
  final int encoding;
  final List<int> raw;
}

/// ID3v1 fields as raw bytes (30 each), e.g. Shift-JIS from old taggers.
class Id3v1Fields {
  const Id3v1Fields({
    this.title = const [],
    this.artist = const [],
    this.album = const [],
  });

  final List<int> title;
  final List<int> artist;
  final List<int> album;

  List<int> bytes() {
    List<int> field(List<int> raw) => [
      ...raw.take(30),
      ...List.filled(30 - raw.take(30).length, 0),
    ];
    return [
      ...ascii.encode('TAG'),
      ...field(title),
      ...field(artist),
      ...field(album),
      ...List.filled(4 + 30, 0), // year, comment
      255, // genre: none
    ];
  }
}
