import 'dart:convert';

import '../../../core/tags/id3.dart';
import '../../../core/utils/text_normalize.dart';

/// The tag fields that a file's own tags can correct.
class SongTags {
  const SongTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.year,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int? year;

  @override
  bool operator ==(Object other) =>
      other is SongTags &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.albumArtist == albumArtist &&
      other.genre == genre &&
      other.trackNumber == trackNumber &&
      other.discNumber == discNumber &&
      other.year == year;

  @override
  int get hashCode => Object.hash(
    title,
    artist,
    album,
    albumArtist,
    genre,
    trackNumber,
    discNumber,
    year,
  );

  @override
  String toString() =>
      'SongTags($title, $artist, $album, $albumArtist, $genre, '
      '$trackNumber, $discNumber, $year)';
}

/// Combines MediaStore's tags with the file's own [file] tags:
/// - missing values are filled from the file; existing ones always win;
/// - text is replaced only when MediaStore's is a misreading of the
///   file's: the two differ solely in non-ASCII characters (a code-page
///   mix-up), or MediaStore's is the file's UTF-8 read as Latin-1 /
///   Windows-1252 (Android 9's scanner). Other mojibake (Shift-JIS, GBK,
///   …) is repaired on the platform before it gets here.
SongTags mergeTags(SongTags mediaStore, SongTags file) => SongTags(
  title: _mergeText(mediaStore.title, file.title),
  artist: _mergeText(mediaStore.artist, file.artist),
  album: _mergeText(mediaStore.album, file.album),
  albumArtist: mediaStore.albumArtist ?? file.albumArtist,
  genre: mediaStore.genre ?? file.genre,
  trackNumber: mediaStore.trackNumber ?? file.trackNumber,
  discNumber: mediaStore.discNumber ?? file.discNumber,
  year: mediaStore.year ?? file.year,
);

String? _mergeText(String? mediaStore, String? file) {
  if (mediaStore == null) return file;
  if (file == null || file == mediaStore) return mediaStore;
  if (isEncodingVariant(mediaStore, file)) return file;
  if (isUtf8Mojibake(mediaStore, file)) return file;
  return isByteSwapped(mediaStore, file) ? file : mediaStore;
}

/// True when [garbled] is [text] read as UTF-16 in the wrong byte order
/// (MediaStore with a big-endian ID3 frame without a BOM), the units that
/// makes invalid dropped, and [text] reads clearly more plausibly. So a
/// correct MediaStore title never gives way to a wrong guess of ours.
bool isByteSwapped(String garbled, String text) {
  if (garbled.isEmpty || garbled == text) return false;
  // Platforms differ in which invalid units they drop: compare without any.
  String valid(Iterable<int> units) =>
      String.fromCharCodes(units.where(_validUnit));
  final swapped = valid(
    text.codeUnits.map((u) => ((u & 0xFF) << 8) | (u >> 8)),
  );
  return swapped.isNotEmpty &&
      swapped == valid(garbled.codeUnits) &&
      textPlausibility(text) > textPlausibility(garbled) + 2;
}

bool _validUnit(int u) =>
    u >= 0x20 &&
    !(u >= 0x7F && u < 0xA0) &&
    !(u >= 0xD800 && u < 0xF900) && // surrogates, private use
    !(u >= 0xFDD0 && u < 0xFDF0) &&
    u != 0xFFFE &&
    u != 0xFFFF;

/// True when [garbled] is exactly [text]'s UTF-8 bytes read as Latin-1 or
/// Windows-1252, and [text] itself is clean (no control or replacement
/// characters). A correct [garbled] never matches: it would have to be
/// the garbled form of [text].
bool isUtf8Mojibake(String garbled, String text) {
  if (!hasNonAscii(text) || garbled == text) return false;
  if (text.runes.any(_isControlOrReplacement)) return false;
  final bytes = utf8.encode(text);
  if (garbled.length != bytes.length) return false;
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    final c = garbled.codeUnitAt(i);
    if (c == b) continue; // Latin-1 (and ASCII)
    if (b >= 0x80 && b <= 0x9F && _cp1252[b - 0x80] == c) continue;
    return false;
  }
  return true;
}

bool _isControlOrReplacement(int rune) =>
    (rune < 0x20 && rune != 0x09) ||
    (rune >= 0x7F && rune <= 0x9F) ||
    rune == 0xFFFD;

/// Windows-1252 for bytes 0x80-0x9F (0 where it has no character: there
/// Windows, like Latin-1, gives U+0080-U+009F, matched above).
const _cp1252 = [
  0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
  0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
];

/// True when [a] and [b] have the same length, differ somewhere, and every
/// difference is between two non-ASCII characters ("Seńorita" vs
/// "Señorita").
bool isEncodingVariant(String a, String b) {
  if (a.length != b.length || a == b) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a.codeUnitAt(i);
    final y = b.codeUnitAt(i);
    if (x != y && (x <= 0x7F || y <= 0x7F)) return false;
  }
  return true;
}

/// Whether a song's MediaStore tags are worth checking against the file.
/// A missing album artist alone is not a reason: most files simply have
/// none. It is still filled in when the file is read for another reason.
bool needsFileTags(SongTags tags) =>
    tags.year == null ||
    tags.genre == null ||
    tags.trackNumber == null ||
    [tags.title, tags.artist, tags.album].nonNulls.any(hasNonAscii);
