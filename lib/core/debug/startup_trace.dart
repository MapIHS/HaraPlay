import 'dart:ui' show FrameTiming;

import 'package:flutter/widgets.dart';

/// Logs how long each startup step takes. Enabled with
/// `--dart-define=HARAPLAY_STARTUP_TRACE=true` (profile builds); each line
/// carries the wall-clock time, to line it up with logcat's process start.
abstract final class StartupTrace {
  static const enabled = bool.fromEnvironment('HARAPLAY_STARTUP_TRACE');

  static final _clock = Stopwatch();
  static var _last = Duration.zero;

  /// Call first thing in `main`.
  static void start() {
    if (!enabled) return;
    _clock.start();
    mark('main');
    WidgetsBinding.instance
      ..waitUntilFirstFrameRasterized.then(
        (_) => mark('first frame rasterized'),
      )
      ..addTimingsCallback(_firstFrame);
  }

  static void _firstFrame(List<FrameTiming> timings) {
    WidgetsBinding.instance.removeTimingsCallback(_firstFrame);
    final t = timings.first;
    debugPrint(
      'HaraPlay startup: first frame build '
      '${t.buildDuration.inMilliseconds} ms, raster '
      '${t.rasterDuration.inMilliseconds} ms',
    );
  }

  static void mark(String step) {
    if (!enabled) return;
    final now = _clock.elapsed;
    debugPrint(
      'HaraPlay startup: ${now.inMilliseconds} ms '
      '(+${(now - _last).inMilliseconds}) $step '
      '@${DateTime.now().millisecondsSinceEpoch}',
    );
    _last = now;
  }
}
