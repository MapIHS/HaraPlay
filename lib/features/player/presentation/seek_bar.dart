import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import 'player_providers.dart';

/// Whether the seek bar's wave moves; tests turn it off.
final seekWaveMotionProvider = Provider<bool>((ref) => true);

/// How far one accessibility increase / decrease moves.
const seekStep = Duration(seconds: 10);

/// The Now Playing progress bar: the played part is a gently moving wave
/// while the song plays; it flattens when paused or while scrubbing. Tap
/// or drag anywhere along it to seek; while dragging, a bubble above the
/// thumb shows the time, and the player seeks once on release.
class SeekBar extends ConsumerStatefulWidget {
  const SeekBar({super.key, required this.duration, required this.playing});

  /// The touch area that holds the track (finders in tests).
  static const trackKey = ValueKey('seek-bar-track');

  /// Height of the touch area.
  static const double height = 48;

  final Duration duration;
  final bool playing;

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar>
    with TickerProviderStateMixin {
  /// The scrubbed fraction while a finger is down.
  double? _scrub;

  /// 0 = flat line, 1 = full wave.
  late final AnimationController _amplitude = AnimationController(
    vsync: this,
    duration: HaraMotion.slow,
  );

  /// Drives the wave's sideways motion; one cycle per period.
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// The wave holds still under "Remove animations", and in widget tests
  /// (an endless motion never lets `pumpAndSettle` finish).
  bool _still = false;
  bool? _wavy;

  @override
  void initState() {
    super.initState();
    // Stop the motion once the wave has flattened, so a paused song does
    // not repaint every frame.
    _amplitude.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _phase.stop();
    });
  }

  void _updateWave() {
    final wavy = widget.playing && _scrub == null;
    if (wavy == _wavy) return;
    _wavy = wavy;
    if (_still) {
      // A still wave while playing: no movement and no easing.
      _amplitude.value = wavy ? 1 : 0;
      _phase.stop();
    } else if (wavy) {
      _amplitude.forward();
      if (!_phase.isAnimating) _phase.repeat();
    } else {
      _amplitude.reverse();
    }
  }

  @override
  void dispose() {
    _amplitude.dispose();
    _phase.dispose();
    super.dispose();
  }

  int get _totalMs => widget.duration.inMilliseconds;

  double _fractionAt(double dx, double width) {
    final span = width - 2 * _WavePainter.inset;
    if (span <= 0) return 0;
    return ((dx - _WavePainter.inset) / span).clamp(0.0, 1.0);
  }

  Duration _at(double fraction) =>
      Duration(milliseconds: (fraction * _totalMs).round());

  void _startScrub(double fraction) => setState(() => _scrub = fraction);

  void _endScrub({bool seek = true}) {
    final fraction = _scrub;
    if (fraction == null) return;
    if (seek) ref.read(playerProvider).seek(_at(fraction));
    setState(() => _scrub = null);
  }

  void _seekBy(Duration delta, Duration from) {
    final target = from + delta;
    ref
        .read(playerProvider)
        .seek(
          target < Duration.zero
              ? Duration.zero
              : (target > widget.duration ? widget.duration : target),
        );
  }

  @override
  Widget build(BuildContext context) {
    final still =
        !ref.watch(seekWaveMotionProvider) ||
        MediaQuery.disableAnimationsOf(context);
    if (still != _still) {
      _still = still;
      _wavy = null;
    }
    _updateWave();
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final totalMs = _totalMs;
    final enabled = totalMs > 0;
    final value =
        _scrub ??
        (enabled ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0);
    final shown = _at(value);
    final mono = HaraTextStyles.of(context).mono;
    final colors = HaraColors.of(context);

    String spoken(Duration d) =>
        '${formatDuration(d)} of ${formatDuration(widget.duration)}';

    Duration clamp(Duration d) => d < Duration.zero
        ? Duration.zero
        : (d > widget.duration ? widget.duration : d);

    return Column(
      children: [
        Semantics(
          slider: true,
          label: 'Seek',
          value: spoken(shown),
          increasedValue: spoken(clamp(shown + seekStep)),
          decreasedValue: spoken(clamp(shown - seekStep)),
          onIncrease: enabled ? () => _seekBy(seekStep, shown) : null,
          onDecrease: enabled ? () => _seekBy(-seekStep, shown) : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                key: SeekBar.trackKey,
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapUp: enabled
                    ? (d) => ref
                          .read(playerProvider)
                          .seek(_at(_fractionAt(d.localPosition.dx, width)))
                    : null,
                onHorizontalDragStart: enabled
                    ? (d) => _startScrub(_fractionAt(d.localPosition.dx, width))
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (d) => setState(
                        () => _scrub = _fractionAt(d.localPosition.dx, width),
                      )
                    : null,
                onHorizontalDragEnd: enabled ? (_) => _endScrub() : null,
                onHorizontalDragCancel: enabled
                    ? () => _endScrub(seek: false)
                    : null,
                child: SizedBox(
                  height: SeekBar.height,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _WavePainter(
                      fraction: value,
                      amplitude: _amplitude,
                      phase: _phase,
                      scrubbing: _scrub != null,
                      bubble: _scrub == null ? null : formatDuration(shown),
                      bubbleStyle: HaraTextStyles.of(context).monoStrong
                          .copyWith(color: colors.foreground),
                      active: enabled ? colors.emphasis : colors.border,
                      inactive: colors.surfaceAlt,
                      thumb: colors.emphasis,
                      outline: colors.border,
                      shadow: colors.shadow,
                      bubbleFill: colors.surface,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.lg),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDuration(shown), style: mono),
                Text(remainingLabel(shown, widget.duration), style: mono),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Our own seek-bar drawing: a wave from the start to the thumb, a flat
/// track after it, a bordered round thumb with a hard shadow, and the time
/// bubble while scrubbing.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.fraction,
    required this.amplitude,
    required this.phase,
    required this.scrubbing,
    required this.bubble,
    required this.bubbleStyle,
    required this.active,
    required this.inactive,
    required this.thumb,
    required this.outline,
    required this.shadow,
    required this.bubbleFill,
    required this.textScaler,
  }) : super(repaint: Listenable.merge([amplitude, phase]));

  /// Space at both ends, so the thumb fits at 0 % and 100 %.
  static const double inset = 20;
  static const double strokeWidth = 4;
  static const double waveHeight = 3.5;
  static const double wavelength = 30;
  static const double thumbRadius = 8;
  static const double scrubThumbRadius = 11;

  final double fraction;
  final Animation<double> amplitude;
  final Animation<double> phase;
  final bool scrubbing;
  final String? bubble;
  final TextStyle bubbleStyle;
  final Color active;
  final Color inactive;
  final Color thumb;
  final Color outline;
  final Color shadow;
  final Color bubbleFill;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const start = inset;
    final end = math.max(start, size.width - inset);
    final x = start + (end - start) * fraction;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // The rest of the song: flat.
    if (end > x) {
      canvas.drawLine(Offset(x, cy), Offset(end, cy), stroke..color = inactive);
    }

    // The played part: a sine whose height eases in from the start and
    // tapers into the thumb, so it always meets the track's centre line.
    final a = waveHeight * Curves.easeInOut.transform(amplitude.value);
    final shift = phase.value * 2 * math.pi;
    final path = Path()..moveTo(start, cy);
    if (a < 0.05) {
      path.lineTo(x, cy);
    } else {
      const k = 2 * math.pi / wavelength;
      const step = 2.0;
      for (var px = start; px < x; px += step) {
        final taper = math.min(
          1.0,
          math.min(px - start, x - px) / (wavelength / 2),
        );
        path.lineTo(px, cy + a * taper * math.sin(k * (px - start) - shift));
      }
      path.lineTo(x, cy);
    }
    canvas.drawPath(path, stroke..color = active);

    // Thumb: bordered, with the hard offset shadow.
    final r = scrubbing ? scrubThumbRadius : thumbRadius;
    final centre = Offset(x, cy);
    canvas
      ..drawCircle(
        centre + const Offset(HaraShadow.small, HaraShadow.small),
        r,
        Paint()..color = shadow,
      )
      ..drawCircle(centre, r, Paint()..color = thumb)
      ..drawCircle(
        centre,
        r - HaraBorder.regular / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = HaraBorder.regular
          ..color = outline,
      );

    final label = bubble;
    if (label != null) _paintBubble(canvas, size, x, cy - r, label);
  }

  /// The time above the thumb, kept inside the bar's width. It overhangs
  /// the top of the bar, over the title area, only while scrubbing.
  void _paintBubble(
    Canvas canvas,
    Size size,
    double x,
    double thumbTop,
    String label,
  ) {
    final text = TextPainter(
      text: TextSpan(text: label, style: bubbleStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    const padH = HaraSpacing.sm + 2;
    const padV = HaraSpacing.xs;
    final w = text.width + 2 * padH;
    final h = text.height + 2 * padV;
    final left = (x - w / 2)
        .clamp(0.0, math.max(0.0, size.width - w))
        .toDouble();
    final top = thumbTop - HaraSpacing.sm - h;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(HaraRadius.sm),
    );
    canvas
      ..drawRRect(
        rect.shift(const Offset(HaraShadow.small, HaraShadow.small)),
        Paint()..color = shadow,
      )
      ..drawRRect(rect, Paint()..color = bubbleFill)
      ..drawRRect(
        rect.deflate(HaraBorder.regular / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = HaraBorder.regular
          ..color = outline,
      );
    text.paint(canvas, Offset(left + padH, top + padV));
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.fraction != fraction ||
      old.scrubbing != scrubbing ||
      old.bubble != bubble ||
      old.active != active ||
      old.inactive != inactive ||
      old.thumb != thumb ||
      old.outline != outline ||
      old.shadow != shadow ||
      old.bubbleFill != bubbleFill ||
      old.bubbleStyle != bubbleStyle ||
      old.textScaler != textScaler ||
      old.amplitude != amplitude ||
      old.phase != phase;
}

/// "-0:30" for 15 s into 45 s. Elapsed time rounds down, so remaining time
/// rounds up, and the two always add up to the length.
String remainingLabel(Duration elapsed, Duration total) {
  final remainingMs = (total - elapsed).inMilliseconds.clamp(0, 1 << 62);
  return '-${formatDuration(Duration(seconds: (remainingMs / 1000).ceil()))}';
}
