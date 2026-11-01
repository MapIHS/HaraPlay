/// Helpers for Settings › Library › Excluded folders.
library;

/// The storage volume a path lives on: `/storage/emulated/0` for the
/// phone's own storage, `/storage/1A2B-3C4D` for an SD card. Null if the
/// path is not under `/storage`.
String? volumeRoot(String path) {
  final parts = path.split('/');
  // ['', 'storage', 'emulated', '0', ...] or ['', 'storage', 'ABCD-1234', ...]
  if (parts.length < 3 || parts[1] != 'storage') return null;
  if (parts[2] == 'emulated') {
    return parts.length < 4 ? null : parts.take(4).join('/');
  }
  return parts.take(3).join('/');
}

/// [path] as people know it: "Music/WhatsApp Audio" on the phone's own
/// storage, "SD card · Music" on another volume.
String displayFolder(String path) {
  final root = volumeRoot(path);
  if (root == null) return path;
  final rest = path.length > root.length ? path.substring(root.length + 1) : '';
  if (root.startsWith('/storage/emulated/')) {
    return rest.isEmpty ? 'Phone storage' : rest;
  }
  return rest.isEmpty ? 'SD card' : 'SD card · $rest';
}

/// Whether [path] is [folder] or inside it.
bool isInsideFolder(String path, String folder) =>
    path == folder || path.startsWith('$folder/');

/// A folder the user can exclude, with the number of songs in it and its
/// subfolders.
typedef FolderChoice = ({String path, int songCount});

/// Every folder that holds songs, plus the folders above them (down to,
/// but not including, the storage root), sorted by path. Folders that
/// are already excluded, or inside an excluded one, are left out.
List<FolderChoice> folderChoices(
  Map<String, int> songsByFolder,
  List<String> excluded,
) {
  final counts = <String, int>{};
  for (final MapEntry(key: folder, value: n) in songsByFolder.entries) {
    final root = volumeRoot(folder);
    var current = folder;
    while (true) {
      counts[current] = (counts[current] ?? 0) + n;
      final slash = current.lastIndexOf('/');
      if (slash <= 0) break;
      final parent = current.substring(0, slash);
      if (root == null || parent.length <= root.length) break;
      current = parent;
    }
  }
  final paths =
      counts.keys
          .where(
            (path) => !excluded.any((folder) => isInsideFolder(path, folder)),
          )
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [for (final path in paths) (path: path, songCount: counts[path]!)];
}

/// [excluded] with [folder] added; folders inside it become redundant and
/// are dropped.
List<String> addExcludedFolder(List<String> excluded, String folder) => [
  for (final existing in excluded)
    if (!isInsideFolder(existing, folder)) existing,
  folder,
]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
