import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/media_store_channel.dart';
import '../../../core/storage/preferences.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../presentation/library_providers.dart';

/// Rescans the library when MediaStore reports changed music files, so
/// songs copied, downloaded or deleted while the app runs show up (or go)
/// without a manual rescan. Changes that arrive during a rescan trigger
/// one more afterwards.
class AutoRescan {
  AutoRescan({
    required this._changes,
    required this._sync,
    required this._enabled,
  });

  final Stream<void> _changes;
  final Future<void> Function() _sync;
  final bool Function() _enabled;

  StreamSubscription<void>? _subscription;
  bool _running = false;
  bool _pending = false;

  void start() => _subscription ??= _changes.listen((_) => _onChange());

  void _onChange() {
    if (!_enabled()) return;
    if (_running) {
      _pending = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    try {
      await _sync();
    } on Object {
      // A failed background rescan is retried on the next change; the
      // error stays visible in the sync controller's state.
    } finally {
      _running = false;
    }
    if (_pending) {
      _pending = false;
      unawaited(_run());
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Started by `bootstrap()` once media access is granted.
final autoRescanProvider = Provider<AutoRescan>((ref) {
  final rescan = AutoRescan(
    changes: ref.watch(mediaSourceProvider).changes,
    sync: () => ref.read(librarySyncControllerProvider.notifier).sync(),
    // Before onboarding finishes, its own first scan is in charge.
    enabled: () =>
        OnboardingRepository(ref.read(sharedPreferencesProvider))
            .readCompleted(),
  );
  ref.onDispose(rescan.dispose);
  rescan.start();
  return rescan;
});
