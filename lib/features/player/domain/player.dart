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

  // Queue editing. Positions are play-order indexes (as in the queue
  // sheet). None of these interrupts the current song.

  /// Inserts [songs] right after the current song. Starts playback when
  /// the queue is empty.
  Future<void> playNext(List<QueueSong> songs);

  /// Appends [songs] to the end of the queue. Starts playback when the
  /// queue is empty.
  Future<void> addToQueue(List<QueueSong> songs);

  /// Removes the entry at [index]; the current song cannot be removed.
  Future<void> removeFromQueue(int index);

  /// Moves the entry at [from] so that it ends up at [to].
  Future<void> moveInQueue(int from, int to);

  /// Removes every song after the current one.
  Future<void> clearUpcoming();

  /// Plays the entry at [index] from its start.
  Future<void> skipTo(int index);
}
