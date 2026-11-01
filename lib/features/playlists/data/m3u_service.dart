import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/playlists_dao.dart';
import '../../../core/platform/document_files.dart';
import '../../../core/utils/text_decode.dart';
import '../domain/m3u.dart';
import '../domain/playlist_models.dart';
import '../presentation/playlist_providers.dart';

/// What an import did, for the message shown afterwards.
/// [playlistId] is null when no song was found (no playlist is made).
typedef M3uImport = ({int? playlistId, String name, int found, int missing});

/// Exports playlists to `.m3u` files and imports them back, through the
/// document picker.
class M3uService {
  M3uService(this._dao, this._files, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PlaylistsDao _dao;
  final DocumentFiles _files;
  final DateTime Function() _clock;

  /// Types a picker may label playlists with (some file managers use
  /// generic ones).
  static const openTypes = [
    'audio/x-mpegurl',
    'audio/mpegurl',
    'application/x-mpegurl',
    'application/vnd.apple.mpegurl',
    'application/octet-stream',
    'text/plain',
  ];

  /// Saves [playlist] where the user chooses. Returns the file name, or
  /// null if the user cancelled.
  Future<String?> export(PlaylistSummary playlist) async {
    final entries = await _dao.watchEntries(playlist.id).first;
    final text = writeM3u([
      for (final e in entries)
        (
          path: e.song.path,
          title: e.song.title,
          artist: e.song.artist,
          duration: Duration(milliseconds: e.song.durationMs),
        ),
    ]);
    return _files.save(
      fileName: m3uFileName(playlist.name),
      mimeType: 'audio/x-mpegurl',
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
  }

  /// Lets the user pick an `.m3u` file and makes a new playlist of the
  /// songs found in the library, named after the file. Null if the user
  /// cancelled. When no song is found, no playlist is made.
  Future<M3uImport?> import() async {
    final file = await _files.open(mimeTypes: openTypes);
    if (file == null) return null;
    final locations = parseM3u(decodeTextFile(file.bytes));
    final match = matchM3u(
      locations,
      await _dao.songPaths(),
      playlistPath: file.path,
    );
    if (match.songIds.isEmpty) {
      return (
        playlistId: null,
        name: playlistNameFromFile(file.name),
        found: 0,
        missing: match.missing.length,
      );
    }
    final existing = await _dao.watchPlaylists().first;
    final name = uniquePlaylistName(
      cleanPlaylistName(playlistNameFromFile(file.name)) ?? 'Imported playlist',
      existing.map((p) => p.name),
    );
    final at = _clock();
    final id = await _dao.create(name, at: at);
    await _dao.addSongs(id, match.songIds, at: at);
    return (
      playlistId: id,
      name: name,
      found: match.songIds.length,
      missing: match.missing.length,
    );
  }
}

final m3uServiceProvider = Provider<M3uService>(
  (ref) => M3uService(
    ref.watch(playlistsDaoProvider),
    ref.watch(documentFilesProvider),
  ),
);

/// "Imported 12 songs." / "Imported 12 of 14 songs; 2 aren't on this
/// phone." / "None of the 3 songs are on this phone."
String describeImport(M3uImport result) {
  final total = result.found + result.missing;
  String songs(int n) => n == 1 ? '1 song' : '$n songs';
  if (total == 0) return 'The file lists no songs.';
  if (result.found == 0) {
    return total == 1
        ? "The song in this file isn't on this phone."
        : 'None of the $total songs in this file are on this phone.';
  }
  if (result.missing == 0) return 'Imported ${songs(result.found)}.';
  final verb = result.missing == 1 ? "isn't" : "aren't";
  return 'Imported ${result.found} of ${songs(total)}; '
      '${result.missing} $verb on this phone.';
}
