import 'dart:convert';
import 'dart:typed_data';

/// Text of a lyrics or playlist file: UTF-8 or UTF-16 (with a byte-order mark), else
/// UTF-8, falling back to Latin-1 for older files.
String decodeTextFile(Uint8List bytes) {
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
