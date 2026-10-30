import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/platform/media_store_channel.dart';

/// Whether HaraPlay may read the music library.
enum MediaAccess {
  granted,

  /// Not granted; asking again shows the system dialog.
  denied,

  /// Not granted and Android will not show the dialog again; the user has to
  /// allow it in system settings. Only known after a request.
  permanentlyDenied,
}

/// Wraps permission_handler with HaraPlay's rules:
/// READ_MEDIA_AUDIO on API 33+, READ_EXTERNAL_STORAGE on API 24-32, and a
/// non-blocking POST_NOTIFICATIONS request on API 33+.
class MediaPermissionService {
  MediaPermissionService({required this.sdkInt});

  final int sdkInt;

  bool get _usesMediaAudio => sdkInt >= 33;

  Permission get _libraryPermission =>
      _usesMediaAudio ? Permission.audio : Permission.storage;

  /// Current status without prompting. Android cannot report "permanently
  /// denied" here, so a denial always reads as [MediaAccess.denied].
  Future<MediaAccess> check() async =>
      _toAccess(await _libraryPermission.status);

  /// Shows the system dialog (if Android still allows it).
  Future<MediaAccess> request() async =>
      _toAccess(await _libraryPermission.request());

  /// Asks for the playback notification on API 33+. Called once at the end
  /// of onboarding; the answer never blocks the app.
  Future<void> requestNotifications() async {
    if (_usesMediaAudio) await Permission.notification.request();
  }

  Future<bool> openSettings() => openAppSettings();

  static MediaAccess _toAccess(PermissionStatus status) => switch (status) {
    PermissionStatus.granted || PermissionStatus.limited => MediaAccess.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => MediaAccess.permanentlyDenied,
    _ => MediaAccess.denied,
  };
}

final mediaPermissionServiceProvider = Provider<MediaPermissionService>(
  (ref) => MediaPermissionService(sdkInt: ref.watch(sdkIntProvider)),
);
