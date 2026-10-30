import 'dart:typed_data';

import 'package:haraplay/core/platform/media_source.dart';
import 'package:haraplay/core/platform/media_store_song.dart';
import 'package:haraplay/features/onboarding/data/media_permission_service.dart';

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
