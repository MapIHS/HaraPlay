import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:haraplay/core/artwork/artwork_cache.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/library_dao.dart';
import 'package:haraplay/core/platform/media_source.dart';
import 'package:haraplay/core/platform/media_store_song.dart';
import 'package:haraplay/features/library/data/file_tag_reader.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';
import 'package:haraplay/features/lyrics/data/lyrics_loader.dart';
import 'package:haraplay/features/lyrics/domain/lyrics.dart';
import 'package:haraplay/features/onboarding/data/media_permission_service.dart';
import 'package:haraplay/features/player/domain/player.dart';
import 'package:haraplay/features/player/domain/queue_model.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/domain/sleep_timer_state.dart';

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

  @override
  Future<int> prune(Map<int, int> versions) async => 0;
}

/// Records what the UI asks the player to do. Queue edits run on a real
/// [QueueModel], so widget tests see the same queue the app would.
class FakePlayer implements Player {
  final _sleep = StreamController<SleepTimerState>.broadcast();
  SleepTimerState sleepState = const SleepTimerOff();

  void _setSleep(SleepTimerState state) {
    sleepState = state;
    _sleep.add(state);
  }

  @override
  Stream<SleepTimerState> get sleepTimer async* {
    yield sleepState;
    yield* _sleep.stream;
  }

  @override
  void startSleepTimer(Duration duration) =>
      _setSleep(SleepCountdown(endsAt: clock.now().add(duration)));

  @override
  void sleepAtEndOfTrack() => _setSleep(const SleepAtEndOfTrack());

  @override
  void cancelSleepTimer() => _setSleep(const SleepTimerOff());

  final _status = StreamController<PlaybackStatus>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  PlaybackStatus _current = PlaybackStatus.idle;
  QueueModel _queue = QueueModel(const []);
  int _index = 0;

  final played = <(List<QueueSong>, int, PlaySource)>[];
  final labels = <String?>[];
  final shuffleArgs = <bool?>[];
  final seeks = <Duration>[];
  int toggles = 0;
  int nexts = 0;
  int previouses = 0;

  List<int> get queueIds => [for (final s in _queue.songs) s.id];
  int get currentIndex => _index;

  void emit(PlaybackStatus status) {
    _current = status;
    _status.add(status);
  }

  void emitPosition(Duration position) => _position.add(position);

  void _emitQueue({bool? playing}) {
    final songs = _queue.songs;
    emit(
      PlaybackStatus(
        song: songs.isEmpty ? null : songs[_index],
        playing: playing ?? _current.playing,
        buffering: false,
        duration: songs.isEmpty ? Duration.zero : songs[_index].duration,
        shuffle: _queue.shuffled,
        repeat: _current.repeat,
        source: _current.source,
        sourceLabel: _current.sourceLabel,
        queue: songs,
        queueIndex: _index,
      ),
    );
  }

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
    _queue = QueueModel(songs);
    _index = startIndex;
    _current = PlaybackStatus(
      song: null,
      playing: true,
      buffering: false,
      duration: Duration.zero,
      repeat: _current.repeat,
      source: source,
      sourceLabel: sourceLabel,
    );
    _emitQueue(playing: true);
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

  @override
  Future<void> playNext(List<QueueSong> songs) async {
    if (_queue.length == 0) {
      return playSongs(songs, source: PlaySource.queue);
    }
    _queue.insert(_index + 1, songs);
    _emitQueue();
  }

  @override
  Future<void> addToQueue(List<QueueSong> songs) async {
    if (_queue.length == 0) {
      return playSongs(songs, source: PlaySource.queue);
    }
    _queue.insert(_queue.length, songs);
    _emitQueue();
  }

  @override
  Future<void> removeFromQueue(int index) async {
    if (index == _index) return;
    _queue.removeAt(index);
    if (index < _index) _index--;
    _emitQueue();
  }

  @override
  Future<void> moveInQueue(int from, int to) async {
    _queue.move(from, to);
    if (from == _index) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index--;
    } else if (from > _index && to <= _index) {
      _index++;
    }
    _emitQueue();
  }

  @override
  Future<void> clearUpcoming() async {
    _queue.removeRange(_index + 1, _queue.length);
    _emitQueue();
  }

  int dropMissingCalls = 0;

  @override
  Future<void> dropMissing() async => dropMissingCalls++;

  @override
  Future<void> skipTo(int index) async {
    _index = index;
    _emitQueue();
  }
}

/// Lyrics by audio path, answered at once (the real loader uses an
/// isolate, which the widget-test clock never lets finish).
class FakeLyricsLoader extends LyricsLoader {
  FakeLyricsLoader([this.byPath = const {}]);

  final Map<String, String> byPath;

  @override
  Future<Lyrics?> load(String audioPath) async {
    final text = byPath[audioPath];
    if (text == null) return null;
    final lyrics = parseLyrics(text);
    return lyrics.isEmpty ? null : lyrics.withSource(LyricsSource.sidecar);
  }
}
