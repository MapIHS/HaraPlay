import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_source.dart';
import 'media_store_song.dart';

/// Dart side of the `haraplay/media` channel (see `MediaStorePlugin.kt`).
class MediaStoreChannel implements MediaSource {
  MediaStoreChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('haraplay/media') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'mediaChanged') _changes.add(null);
    });
  }

  final MethodChannel _channel;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  /// Android API level, e.g. 28 for Android 9.
  Future<int> sdkInt() async => await _channel.invokeMethod<int>('sdkInt') ?? 0;

  /// [sdkInt], waiting for `MainActivity` to register the channel first.
  ///
  /// After a reboot, a system media browser (Bluetooth, Android Auto) can
  /// bind audio_service's service before the app is opened; audio_service
  /// then runs `main()` in a background engine that has none of our
  /// channels. Failing there left the app stuck on its splash screen when
  /// the user opened it later. Instead, startup waits here until the
  /// activity attaches to the engine.
  Future<int> sdkIntWhenReady({
    Duration interval = const Duration(milliseconds: 250),
  }) => retryUntilRegistered(sdkInt, interval: interval);

  @override
  Future<List<MediaStoreSong>> querySongs() async {
    final reply = await _channel.invokeMapMethod<Object?, Object?>(
      'querySongs',
    );
    final songs = reply == null
        ? const <MediaStoreSong>[]
        : MediaStoreSong.fromColumns(reply);

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

  /// Repairs mojibake (see `TextRepair.kt`): (text, hint) → text.
  Future<List<String?>> repairText(List<(String?, String?)> items) async {
    final reply = await _channel.invokeListMethod<String?>('repairText', {
      'items': [
        for (final (text, hint) in items) [text, hint],
      ],
    });
    return reply ?? [for (final (text, _) in items) text];
  }

  /// [image] (any format Android decodes) cropped to its centre square and
  /// scaled down to at most [sizePx], as JPEG; null if it isn't an image.
  Future<Uint8List?> scaleArtwork(Uint8List image, int sizePx) =>
      _channel.invokeMethod<Uint8List>('scaleArtwork', {
        'image': image,
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

/// Calls [call] until its platform channel has a handler (no more
/// [MissingPluginException]); other errors are passed on.
Future<T> retryUntilRegistered<T>(
  Future<T> Function() call, {
  Duration interval = const Duration(milliseconds: 250),
}) async {
  while (true) {
    try {
      return await call();
    } on MissingPluginException {
      await Future<void>.delayed(interval);
    }
  }
}
