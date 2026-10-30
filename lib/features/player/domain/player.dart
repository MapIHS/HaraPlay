import '../../../core/database/app_database.dart';
import 'queue_song.dart';

/// What the UI can do with playback. Implemented by `HaraAudioHandler`;
/// widget tests use a fake.
abstract interface class Player {
  Stream<PlaybackStatus> get status;
  PlaybackStatus get currentStatus;
  Stream<Duration> get position;

  /// Replaces the queue with [songs] and plays from [startIndex].
  Future<void> playSongs(
    List<QueueSong> songs, {
    int startIndex = 0,
    required PlaySource source,
  });

  Future<void> togglePlay();
  Future<void> next();
  Future<void> previous();
}
