import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_source.dart';
import 'media_store_song.dart';

/// Dart side of the `haraplay/media` channel (see `MediaStorePlugin.kt`).
class MediaStoreChannel implements MediaSource {
  MediaStoreChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('haraplay/media');

  final MethodChannel _channel;

  /// Android API level, e.g. 28 for Android 9.
  Future<int> sdkInt() async => await _channel.invokeMethod<int>('sdkInt') ?? 0;

  @override
  Future<List<MediaStoreSong>> querySongs() async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('querySongs') ??
        const [];
    final songs = <MediaStoreSong>[];
    for (final row in rows) {
      final song = MediaStoreSong.tryParse(row);
      if (song != null) songs.add(song);
    }

    // Below API 30 the audio table has no GENRE column; genres come from a
    // separate membership query instead.
    if (songs.isEmpty || await sdkInt() >= 30) return songs;
    final genreOf = await _genreBySongId();
    return [for (final s in songs) s.withGenre(genreOf[s.id])];
  }

  /// Song ID → genre name. A song in several genres keeps the first one.
  Future<Map<int, String>> _genreBySongId() async {
    final membership =
        await _channel.invokeMapMethod<String, List<Object?>>(
          'queryGenreMembership',
        ) ??
        const {};
    return genreBySongId(membership);
  }

  @override
  Future<Uint8List?> loadArtwork({
    required int songId,
    int? albumId,
    required int sizePx,
  }) => _channel.invokeMethod<Uint8List>('loadArtwork', {
    'songId': songId,
    'albumId': albumId,
    'sizePx': sizePx,
  });
}

/// Inverts the channel's genre → song IDs map.
@visibleForTesting
Map<int, String> genreBySongId(Map<String, List<Object?>> membership) {
  final result = <int, String>{};
  for (final MapEntry(key: genre, value: ids) in membership.entries) {
    for (final id in ids.whereType<num>()) {
      result.putIfAbsent(id.toInt(), () => genre);
    }
  }
  return result;
}

final mediaStoreChannelProvider = Provider<MediaStoreChannel>(
  (ref) => MediaStoreChannel(),
);

final mediaSourceProvider = Provider<MediaSource>(
  (ref) => ref.watch(mediaStoreChannelProvider),
);

/// Android API level, read once at startup (see `bootstrap.dart`).
final sdkIntProvider = Provider<int>(
  (ref) => throw UnimplementedError('sdkIntProvider must be overridden'),
);
