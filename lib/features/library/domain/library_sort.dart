/// Sort fields for each library tab.
enum SongSortField { title, artist, album, dateAdded, duration, size }

enum AlbumSortField { title, artist, year, songCount }

enum ArtistSortField { name, songCount }

enum FolderSortField { name, songCount }

enum GenreSortField { name, songCount }

/// A sort field plus direction. Missing values always sort last.
class LibrarySort<F extends Enum> {
  const LibrarySort(this.field, {this.descending = false});

  final F field;
  final bool descending;

  LibrarySort<F> copyWith({F? field, bool? descending}) => LibrarySort(
    field ?? this.field,
    descending: descending ?? this.descending,
  );

  /// Stored as "field:asc" / "field:desc".
  String encode() => '${field.name}:${descending ? 'desc' : 'asc'}';

  static LibrarySort<F>? decode<F extends Enum>(String? value, List<F> fields) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return null;
    final field = fields.where((f) => f.name == parts[0]).firstOrNull;
    if (field == null) return null;
    return LibrarySort(field, descending: parts[1] == 'desc');
  }

  @override
  bool operator ==(Object other) =>
      other is LibrarySort<F> &&
      other.field == field &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);
}
