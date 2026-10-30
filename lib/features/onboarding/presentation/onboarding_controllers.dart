import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/media_permission_service.dart';
import '../data/onboarding_repository.dart';

/// Library access as checked at startup (see `bootstrap.dart`).
final initialMediaAccessProvider = Provider<MediaAccess>(
  (ref) =>
      throw UnimplementedError('initialMediaAccessProvider must be overridden'),
);

/// Current library access. The router sends the user to onboarding whenever
/// this is not [MediaAccess.granted].
class MediaAccessController extends Notifier<MediaAccess> {
  @override
  MediaAccess build() => ref.watch(initialMediaAccessProvider);

  MediaPermissionService get _service =>
      ref.read(mediaPermissionServiceProvider);

  Future<void> request() async => state = await _service.request();

  /// Re-reads the status, e.g. after returning from system settings. Keeps
  /// [MediaAccess.permanentlyDenied] while still denied, since a plain check
  /// cannot tell the two apart.
  Future<void> recheck() async {
    final current = await _service.check();
    if (current == MediaAccess.denied &&
        state == MediaAccess.permanentlyDenied) {
      return;
    }
    state = current;
  }

  Future<bool> openSettings() => _service.openSettings();
}

final mediaAccessProvider =
    NotifierProvider<MediaAccessController, MediaAccess>(
      MediaAccessController.new,
    );

/// Whether the first-run flow has finished.
class OnboardingCompletedController extends Notifier<bool> {
  @override
  bool build() => ref.watch(onboardingRepositoryProvider).readCompleted();

  Future<void> complete() async {
    state = true;
    await ref.read(onboardingRepositoryProvider).writeCompleted();
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedController, bool>(
      OnboardingCompletedController.new,
    );
