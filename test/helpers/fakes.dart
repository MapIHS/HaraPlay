import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:haraplay/core/artwork/artwork_cache.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/library_dao.dart';
import 'package:haraplay/core/platform/media_source.dart';
import 'package:haraplay/core/platform/media_store_song.dart';
import 'package:haraplay/features/library/data/file_tag_reader.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';
import 'package:haraplay/features/onboarding/data/media_permission_service.dart';
import 'package:haraplay/features/player/domain/player.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';

/// Permission service whose answers are scripted by the test.
class FakeMediaPermissionService implements MediaPermissionService {
  FakeMediaPermissionService({
    this.status = MediaAccess.denied,
    List<MediaAccess>? requestResults,
  }) : requestResults = requestResults ?? [MediaAccess.granted];

  /// What [check] returns.
  MediaAccess status;

  /// What successive [request] calls return (the last one repeats).
  final List<MediaAccess> requestResults;
  int requestCount = 0;
  int openSettingsCount = 0;
  int notificationRequestCount = 0;

  @override
  int get sdkInt => 34;

  @override
  Future<MediaAccess> check() async => status;

  @override
  Future<MediaAccess> request() async {
    final index = requestCount.clamp(0, requestResults.length - 1);
    requestCount++;
    return status = requestResults[index];
  }

  @override
  Future<void> requestNotifications() async => notificationRequestCount++;

  @override
  Future<bool> openSettings() async {
    openSettingsCount++;
    return true;
  }
}

class FakeMediaSource implements MediaSource {
  FakeMediaSource([this.songs = const []]);

  List<MediaStoreSong> songs;

  @override
  Future<List<MediaStoreSong>> querySongs() async => songs;

  @override
  Future<Uint8List?> loadArtwork({
    required int songId,
    int? albumId,
    required int sizePx,
  }) async => null;
}

/// A minimal valid song for tests.
MediaStoreSong testSong(
  int id, {
  String? title,
  int? albumId,
  String folder = '/storage/emulated/0/Music',
}) => MediaStoreSong.tryParse({
  'id': id,
  'title': title ?? 'Song $id',
  'albumId': albumId,
  'path': '$folder/song$id.mp3',
  'durationMs': 180000,
})!;

/// Returns scripted tags per path instead of reading files.
class FakeFileTagReader extends FileTagReader {
  FakeFileTagReader([this.tagsByPath = const {}]);

  final Map<String, SongTags> tagsByPath;
  final List<List<String>> batches = [];

  @override
  Future<List<FileTagsResult>> readAll(List<String> paths) async {
    batches.add(paths);
    return [
      for (final path in paths)
        tagsByPath[path] == null
            ? const FileTagsResult.failed()
            : FileTagsResult.read(tagsByPath[path]!),
    ];
  }
}

/// Artwork cache that answers "no artwork" at once, without file IO.
class FakeArtworkCache extends ArtworkCache {
  FakeArtworkCache()
    : super(FakeMediaSource(), () async => Directory.systemTemp);

  final requests = <ArtworkRequest>[];

  @override
  Future<Uint8List?> load(ArtworkRequest request) async {
    requests.add(request);
    return null;
  }
}

/// Records what the UI asks the player to do; statuses are pushed by tests.
class FakePlayer implements Player {
  final _status = StreamController<PlaybackStatus>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  PlaybackStatus _current = PlaybackStatus.idle;

  final played = <(List<QueueSong>, int, PlaySource)>[];
  final labels = <String?>[];
  final shuffleArgs = <bool?>[];
  final seeks = <Duration>[];
  int toggles = 0;
  int nexts = 0;
  int previouses = 0;

  void emit(PlaybackStatus status) {
    _current = status;
    _status.add(status);
  }

  void emitPosition(Duration position) => _position.add(position);

  @override
  Stream<PlaybackStatus> get status async* {
    yield _current;
    yield* _status.stream;
  }

  @override
  PlaybackStatus get currentStatus => _current;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Future<void> playSongs(
    List<QueueSong> songs, {
    int startIndex = 0,
    required PlaySource source,
    String? sourceLabel,
    bool? shuffle,
  }) async {
    played.add((songs, startIndex, source));
    labels.add(sourceLabel);
    shuffleArgs.add(shuffle);
    emit(
      PlaybackStatus(
        song: songs[startIndex],
        playing: true,
        buffering: false,
        duration: songs[startIndex].duration,
        shuffle: shuffle ?? _current.shuffle,
        repeat: _current.repeat,
        source: source,
        sourceLabel: sourceLabel,
        queueLength: songs.length,
        queueIndex: startIndex,
      ),
    );
  }

  @override
  Future<void> togglePlay() async {
    toggles++;
    emit(_current.copyWith(playing: !_current.playing));
  }

  @override
  Future<void> next() async => nexts++;

  @override
  Future<void> previous() async => previouses++;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> setShuffle(bool enabled) async =>
      emit(_current.copyWith(shuffle: enabled));

  @override
  Future<void> setRepeat(RepeatSetting mode) async =>
      emit(_current.copyWith(repeat: mode));
}
