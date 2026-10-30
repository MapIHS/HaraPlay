/// Lower-cases [text] and strips diacritics from Latin letters, so that
/// "Beyoncé" matches "beyonce" and "Ünïcode" matches "unicode".
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    buffer.write(_folded[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

/// The `search_text` column: the folded, space-joined non-null [parts].
String buildSearchText(Iterable<String?> parts) =>
    foldForSearch(parts.nonNulls.join(' '));

/// Whether [text] contains any character outside 7-bit ASCII.
bool hasNonAscii(String text) => text.codeUnits.any((unit) => unit > 0x7F);

// Lower-case Latin-1 Supplement and Latin Extended-A letters → base letters.
final Map<int, String> _folded = _buildFoldTable();

Map<int, String> _buildFoldTable() {
  const groups = {
    'a': 'àáâãäåāăą',
    'ae': 'æ',
    'c': 'çćĉċč',
    'd': 'ďđð',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı',
    'ij': 'ĳ',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņňŉ',
    'o': 'òóôõöøōŏő',
    'oe': 'œ',
    'r': 'ŕŗř',
    's': 'śŝşš',
    'ss': 'ß',
    't': 'ţťŧ',
    'th': 'þ',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
  };
  return {
    for (final MapEntry(key: base, value: letters) in groups.entries)
      for (final rune in letters.runes) rune: base,
  };
}
