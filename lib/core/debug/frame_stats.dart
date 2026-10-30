
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Logs frame build / raster percentiles every [window] frames. Enabled
/// with `--dart-define=HARAPLAY_FRAME_STATS=true` (profile builds).
abstract final class FrameStats {
  static const enabled = bool.fromEnvironment('HARAPLAY_FRAME_STATS');
  static const window = 120;

  static final _build = <int>[];
  static final _raster = <int>[];

  static void start() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _build.add(t.buildDuration.inMicroseconds);
      _raster.add(t.rasterDuration.inMicroseconds);
    }
    if (_build.length < window) return;
    debugPrint(
      'HaraPlay frames: build ${_summary(_build)} | '
      'raster ${_summary(_raster)}',
    );
    _build.clear();
    _raster.clear();
  }

  static String _summary(List<int> micros) {
    final sorted = [...micros]..sort();
    String ms(double q) =>
        (sorted[((sorted.length - 1) * q).round()] / 1000).toStringAsFixed(1);
    final slow = micros.where((m) => m > 16667).length;
    return 'p50 ${ms(0.5)} p90 ${ms(0.9)} p99 ${ms(0.99)} max ${ms(1)} ms, '
        '$slow/${micros.length} over 16.7 ms';
  }
}
