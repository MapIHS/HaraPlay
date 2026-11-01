import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/domain/queue_song.dart';
import '../data/lyrics_loader.dart';
import '../domain/lyrics.dart';

final lyricsLoaderProvider = Provider<LyricsLoader>(
  (ref) => const LyricsLoader(),
);

/// A song's lyrics, or null. Keyed by ID, path and version, so an edited
/// file is read again.
final lyricsProvider = FutureProvider.autoDispose
    .family<Lyrics?, ({int id, String path, int version})>(
      // Files opened from other apps have no path (and no lyrics).
      (ref, song) async => song.path.isEmpty
          ? null
          : ref.watch(lyricsLoaderProvider).load(song.path),
    );

/// The lyrics key for [song].
({int id, String path, int version}) lyricsKey(QueueSong song) =>
    (id: song.id, path: song.path, version: song.version);

/// Whether Now Playing shows lyrics instead of the artwork. Kept for the
/// session, so it stays on from song to song.
class ShowLyricsController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final showLyricsProvider = NotifierProvider<ShowLyricsController, bool>(
  ShowLyricsController.new,
);
