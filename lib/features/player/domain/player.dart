import '../../../core/database/app_database.dart';
import 'queue_song.dart';

/// What the UI can do with playback. Implemented by `HaraAudioHandler`;
/// widget tests use a fake.
abstract interface class Player {
  Stream<PlaybackStatus> get status;
  PlaybackStatus get currentStatus;
  Stream<Duration> get position;

  /// Replaces the queue with [songs] and plays from [startIndex].
  /// [shuffle] turns shuffle on or off for the new queue; null keeps the
  /// current setting. [sourceLabel] names the source ("Night Drive").
  Future<void> playSongs(
    List<QueueSong> songs, {
    int startIndex = 0,
    required PlaySource source,
    String? sourceLabel,
    bool? shuffle,
  });

  Future<void> togglePlay();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);

  /// Reorders the queue (current song first) or restores the original
  /// order, without interrupting the current song.
  Future<void> setShuffle(bool enabled);
  Future<void> setRepeat(RepeatSetting mode);
}
