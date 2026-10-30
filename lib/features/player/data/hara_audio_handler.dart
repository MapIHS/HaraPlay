import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/artwork/artwork_cache.dart';
import '../../../core/database/app_database.dart';
import '../domain/player.dart';
import '../domain/queue_song.dart';
import 'play_event_recorder.dart';

/// Owns the single [AudioPlayer] and the queue, and publishes state to the
/// notification, lock screen and media buttons through audio_service.
/// The app talks to it through the [Player] interface.
class HaraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements Player {
  HaraAudioHandler({
    required this._player,
    required this._recorder,
    required this._artwork,
  }) {
    _subscriptions.addAll([
      _player.playbackEventStream.listen(
        (_) => _broadcastState(),
        onError: (Object _, StackTrace _) => _broadcastState(),
      ),
      _player.playerStateStream.listen(_onPlayerState),
      _player.currentIndexStream.listen(_onIndex),
      _player.positionStream.listen(_recorder.positionChanged),
    ]);
  }

  /// Notification artwork size in pixels.
  static const _artSize = 384;

  /// "Previous" restarts the song when it has played longer than this.
  static const _restartThreshold = Duration(seconds: 3);

  final AudioPlayer _player;
  final PlayEventRecorder _recorder;
  final ArtworkCache _artwork;
  final _subscriptions = <StreamSubscription<Object?>>[];

  List<QueueSong> _songs = const [];
  PlaySource _source = PlaySource.songs;
  final _status = StreamController<PlaybackStatus>.broadcast();
  PlaybackStatus _lastStatus = PlaybackStatus.idle;

  /// Configures audio focus and "becoming noisy" (headphones unplugged).
  Future<void> configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _subscriptions.add(session.becomingNoisyEventStream.listen((_) => pause()));
  }

  // Player interface ---------------------------------------------------------

  @override
  Stream<PlaybackStatus> get status async* {
    yield _lastStatus;
    yield* _status.stream;
  }

  @override
  PlaybackStatus get currentStatus => _lastStatus;

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Future<void> playSongs(
    List<QueueSong> songs, {
    int startIndex = 0,
    required PlaySource source,
  }) async {
    if (songs.isEmpty) return;
    // Even replaying the same song starts a new listen.
    _recorder.trackChanged(null, source: source);
    _songs = List.unmodifiable(songs);
    _source = source;
    queue.add([for (final s in _songs) _mediaItemFor(s)]);
    await _player.setAudioSources(
      [for (final s in _songs) AudioSource.uri(s.uri)],
      initialIndex: startIndex.clamp(0, songs.length - 1),
      initialPosition: Duration.zero,
    );
    await play();
  }

  @override
  Future<void> togglePlay() => _player.playing ? pause() : play();

  @override
  Future<void> next() => skipToNext();

  @override
  Future<void> previous() => skipToPrevious();

  // audio_service callbacks -------------------------------------------------

  @override
  Future<void> play() async {
    if (_songs.isEmpty) return;
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > _restartThreshold || !_player.hasPrevious) {
      _recorder.trackRestarted();
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _songs.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _recorder.flush();
    await super.stop();
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _recorder.flush();
    await _player.dispose();
    await _status.close();
  }

  // State ---------------------------------------------------------------------

  QueueSong? get _currentSong {
    final index = _player.currentIndex;
    return index == null || index >= _songs.length ? null : _songs[index];
  }

  void _onIndex(int? index) {
    final song = _currentSong;
    _recorder.trackChanged(song, source: _source);
    _publishStatus();
    if (song == null) return;
    final item = _mediaItemFor(song);
    mediaItem.add(item);
    unawaited(_attachArtwork(song, item));
  }

  Future<void> _attachArtwork(QueueSong song, MediaItem item) async {
    final file = await _artwork.fileFor(
      ArtworkRequest(
        songId: song.id,
        albumId: song.albumId,
        sizePx: _artSize,
        version: song.version,
      ),
    );
    // Only if the song is still current.
    if (file == null || _currentSong != song) return;
    mediaItem.add(item.copyWith(artUri: file.uri));
  }

  Future<void> _onPlayerState(PlayerState state) async {
    final ready = state.processingState == ProcessingState.ready;
    _recorder.activeChanged(state.playing && ready);
    _publishStatus();
    if (state.processingState == ProcessingState.completed) {
      // End of the queue: back to the start, paused.
      _recorder.trackEnded();
      await _player.pause();
      await _player.seek(Duration.zero, index: 0);
    }
  }

  void _publishStatus() {
    final processing = _player.processingState;
    _lastStatus = PlaybackStatus(
      song: _currentSong,
      playing: _player.playing && processing != ProcessingState.completed,
      buffering:
          processing == ProcessingState.loading ||
          processing == ProcessingState.buffering,
      duration: _player.duration ?? _currentSong?.duration ?? Duration.zero,
    );
    if (!_status.isClosed) _status.add(_lastStatus);
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  static MediaItem _mediaItemFor(QueueSong song) => MediaItem(
    id: song.uri.toString(),
    title: song.title,
    artist: song.displayArtist,
    album: song.displayAlbum,
    duration: song.duration,
    extras: {'songId': song.id},
  );
}
