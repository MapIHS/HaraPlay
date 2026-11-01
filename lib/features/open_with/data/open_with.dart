import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../library/domain/song_matcher.dart';
import '../../player/domain/player.dart';
import '../../player/domain/queue_song.dart';

/// An audio file another app opened with HaraPlay.
typedef OpenedAudio = ({
  Uri uri,
  int? mediaId,
  String? path,
  String? displayName,
  int? size,
  String? title,
  String? artist,
  String? album,
  Duration? duration,
});

OpenedAudio? openedAudioFrom(Object? reply) {
  if (reply is! Map) return null;
  final uri = Uri.tryParse(reply['uri'] as String? ?? '');
  if (uri == null) return null;
  final ms = reply['durationMs'] as int?;
  return (
    uri: uri,
    mediaId: reply['mediaId'] as int?,
    path: reply['path'] as String?,
    displayName: reply['displayName'] as String?,
    size: reply['size'] as int?,
    title: reply['title'] as String?,
    artist: reply['artist'] as String?,
    album: reply['album'] as String?,
    duration: ms == null ? null : Duration(milliseconds: ms),
  );
}

/// Dart side of `haraplay/open` (see `OpenWithPlugin.kt`).
class OpenWithChannel {
  OpenWithChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('haraplay/open');

  final MethodChannel _channel;

  /// Every opened file: the one the app was started with first, then each
  /// later one.
  Stream<OpenedAudio> files() {
    // Lives as long as the app: files can arrive at any time.
    // ignore: close_sinks
    final controller = StreamController<OpenedAudio>();
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'opened') return;
      final file = openedAudioFrom(call.arguments);
      if (file != null) controller.add(file);
    });
    _channel
        .invokeMethod<Object>('initialFile')
        .then((reply) {
          final file = openedAudioFrom(reply);
          if (file != null) controller.add(file);
        })
        .catchError((Object _) {});
    return controller.stream;
  }
}

/// Library lookups the opener needs.
abstract interface class OpenWithLibrary {
  Future<SongRow?> songById(int id);
  Future<SongRow?> songByPath(String path);

  /// A song whose file is called [fileName] and is exactly [size] bytes
  /// (file managers often hand over a link without a path).
  Future<SongRow?> songByFile(String fileName, int size);
}

/// Plays opened files: the library song when the file is in the library
/// (so it is recorded, likable and so on), otherwise the file itself.
class OpenWith {
  OpenWith(this._player, this._library);

  final Player _player;
  final OpenWithLibrary _library;
  var _nextExternalId = -1;

  Future<void> open(OpenedAudio file) async =>
      _player.playOpened(await songFor(file));

  Future<QueueSong> songFor(OpenedAudio file) async {
    final byId = file.mediaId == null
        ? null
        : await _library.songById(file.mediaId!);
    final path = file.path;
    final name = file.displayName ?? path?.split('/').last;
    final size = file.size;
    final row =
        byId ??
        (path == null
            ? null
            : await _library.songByPath(normalizeStoragePath(path))) ??
        (name == null || size == null || size <= 0
            ? null
            : await _library.songByFile(name, size));
    if (row != null) return QueueSong.fromRow(row);
    return QueueSong.external(
      id: _nextExternalId--,
      uri: file.uri,
      title: _title(file),
      artist: _clean(file.artist),
      album: _clean(file.album),
      duration: file.duration ?? Duration.zero,
    );
  }

  static String? _clean(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  /// The tag title, else the file name without its extension.
  static String _title(OpenedAudio file) {
    final title = _clean(file.title);
    if (title != null) return title;
    final name =
        _clean(file.displayName) ??
        _clean(file.path?.split('/').last) ??
        _clean(file.uri.pathSegments.lastOrNull);
    if (name == null) return 'Shared audio';
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

/// [OpenWithLibrary] on the app database (all songs, hidden ones too).
class DatabaseOpenWithLibrary implements OpenWithLibrary {
  DatabaseOpenWithLibrary(this._db);

  final AppDatabase _db;

  @override
  Future<SongRow?> songById(int id) =>
      (_db.select(_db.songs)..where((s) => s.id.equals(id))).getSingleOrNull();

  @override
  Future<SongRow?> songByPath(String path) => (_db.select(
    _db.songs,
  )..where((s) => s.path.equals(path))).getSingleOrNull();

  @override
  Future<SongRow?> songByFile(String fileName, int size) async {
    final sameSize = await (_db.select(
      _db.songs,
    )..where((s) => s.sizeBytes.equals(size))).get();
    // Two copies of the same file: either is right, take the first.
    return sameSize.where((s) => s.path.endsWith('/$fileName')).firstOrNull;
  }
}
