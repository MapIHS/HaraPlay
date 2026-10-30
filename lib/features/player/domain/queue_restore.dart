import '../../../core/database/app_database.dart';
import '../../../core/database/daos/queue_state_dao.dart';
import 'queue_song.dart';
import 'shuffle.dart';

/// The queue to load on launch, worked out from what was saved.
class RestorePlan {
  const RestorePlan({
    required this.songs,
    required this.original,
    required this.order,
    required this.index,
    required this.position,
  });

  /// Play order.
  final List<QueueSong> songs;

  /// Unshuffled order (same as [songs] when [order] is null).
  final List<QueueSong> original;

  /// Shuffle permutation, or null when not shuffled.
  final List<int>? order;
  final int index;
  final Duration position;
}

/// Plans the restore of [saved] with the songs that still exist in [rows].
/// Deleted songs are skipped; if the saved song itself is gone, playback
/// resumes at the start of the next one that exists (or the last one).
RestorePlan? planRestore(SavedQueue saved, Map<int, SongRow> rows) {
  final songs = <QueueSong>[];
  var index = -1;
  var sameSong = false;
  for (final (i, id) in saved.songIds.indexed) {
    final row = rows[id];
    if (row == null) continue;
    if (index < 0 && i >= saved.currentIndex) {
      index = songs.length;
      sameSong = i == saved.currentIndex;
    }
    songs.add(QueueSong.fromRow(row));
  }
  if (songs.isEmpty) return null;
  if (index < 0) index = songs.length - 1;

  var original = songs;
  List<int>? order;
  final originalIds = saved.originalSongIds;
  if (saved.shuffle && originalIds != null) {
    final kept = [
      for (final id in originalIds)
        if (rows[id] != null) QueueSong.fromRow(rows[id]!),
    ];
    order = orderFromIds(
      [for (final s in songs) s.id],
      [for (final s in kept) s.id],
    );
    if (order != null) original = kept;
  }

  return RestorePlan(
    songs: songs,
    original: original,
    order: order,
    index: index,
    position: sameSong ? saved.position : Duration.zero,
  );
}
