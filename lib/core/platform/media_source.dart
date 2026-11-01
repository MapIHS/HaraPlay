import 'dart:typed_data';

import 'media_store_song.dart';

/// Where the music library comes from. The app's implementation is
/// [MediaStoreChannel]; tests use fakes.
abstract interface class MediaSource {
  /// Every music file on the device, with genres filled in on all API levels.
  Future<List<MediaStoreSong>> querySongs();

  /// Cover art as JPEG bytes scaled to fit [sizePx], or null if there is none.
  Future<Uint8List?> loadArtwork({
    required int songId,
    int? albumId,
    required int sizePx,
  });

  /// Fires when music files were added, removed or changed on the device
  /// (after changes have settled for a moment).
  Stream<void> get changes;
}
