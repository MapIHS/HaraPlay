import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../domain/stats_range.dart';

/// "42 min", "3 h 5 min", "No listening".
String listenedLabel(Duration d) =>
    d == Duration.zero ? 'No listening' : formatTotalDuration(d);

/// "21:00–22:00".
String hourRange(int hour) =>
    '${hour.toString().padLeft(2, '0')}:00–'
    '${((hour + 1) % 24).toString().padLeft(2, '0')}:00';

/// The caption under a chart: what the selection shows.
class ChartCaption extends StatelessWidget {
  const ChartCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: HaraSpacing.sm),
      child: Text(
        text,
        style: HaraTextStyles.of(context).mono,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Listening per hour of the day, drawn as 24 bars around a clock face.
/// Tap a bar to see its hour; the busiest hour is selected at first.
class ListeningClock extends StatefulWidget {
  const ListeningClock({super.key, required this.hours});

  final List<Duration> hours;

  @override
  State<ListeningClock> createState() => _ListeningClockState();
}

class _ListeningClockState extends State<ListeningClock> {
  int? _selected;

  int get _peak {
    var best = 0;
    for (var h = 1; h < 24; h++) {
      if (widget.hours[h] > widget.hours[best]) best = h;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final selected = _selected ?? _peak;
    return Semantics(
      label:
          'Listening by hour of day. Most around ${hourRange(_peak)}, '
          '${listenedLabel(widget.hours[_peak])}.',
      excludeSemantics: true,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return GestureDetector(
                  onTapUp: (details) {
                    final hour = _hourAt(details.localPosition, size);
                    if (hour != null) setState(() => _selected = hour);
                  },
                  child: CustomPaint(
                    size: size,
                    painter: _ClockPainter(
                      hours: widget.hours,
                      selected: selected,
                      fill: colors.primary,
                      stroke: colors.border,
                      muted: colors.mutedForeground,
                      emphasis: colors.foreground,
                      label: textTheme.labelSmall!,
                    ),
                  ),
                );
              },
            ),
          ),
          ChartCaption(
            '${hourRange(selected)} · ${listenedLabel(widget.hours[selected])}',
          ),
        ],
      ),
    );
  }

  /// The hour whose wedge contains [p], or null near the centre.
  static int? _hourAt(Offset p, Size size) {
    final c = size.center(Offset.zero);
    final d = p - c;
    if (d.distance < size.shortestSide * 0.12) return null;
    // 0 at the top, clockwise.
    var angle = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    return ((angle / (2 * math.pi) * 24).round()) % 24;
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({
    required this.hours,
    required this.selected,
    required this.fill,
    required this.stroke,
    required this.muted,
    required this.emphasis,
    required this.label,
  });

  final List<Duration> hours;
  final int selected;
  final Color fill;
  final Color stroke;
  final Color muted;
  final Color emphasis;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final inner = radius * 0.3;
    final outer = radius * 0.86;
    final max = hours.fold(0, (m, d) => math.max(m, d.inMilliseconds));
    final width = 2 * math.pi * inner / 24 * 0.62;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = HaraBorder.thin
      ..color = stroke;
    canvas.drawCircle(c, inner - 4, ring);

    for (var h = 0; h < 24; h++) {
      final ms = hours[h].inMilliseconds;
      final length = max == 0 || ms == 0
          ? 3.0
          : math.max(6.0, (outer - inner) * ms / max);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(h * 2 * math.pi / 24);
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTRB(-width / 2, -(inner + length), width / 2, -inner),
        Radius.circular(width / 3),
      );
      final isSelected = h == selected;
      canvas.drawRRect(
        bar,
        Paint()
          ..color = ms == 0
              ? muted.withValues(alpha: 0.35)
              : isSelected
              ? emphasis
              : fill,
      );
      if (ms > 0) {
        canvas.drawRRect(
          bar,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = HaraBorder.thin
            ..color = stroke,
        );
      }
      canvas.restore();
    }

    // Hour labels at 0, 6, 12 and 18.
    for (final h in [0, 6, 12, 18]) {
      final angle = h * 2 * math.pi / 24 - math.pi / 2;
      final at = c + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.95);
      final painter = TextPainter(
        text: TextSpan(text: h.toString().padLeft(2, '0'), style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.hours != hours ||
      old.selected != selected ||
      old.fill != fill ||
      old.stroke != stroke;
}

/// Listening per weekday, Monday first, as bordered bars. Tap a bar for
/// its total.
class WeekdayBars extends StatefulWidget {
  const WeekdayBars({super.key, required this.days});

  final List<Duration> days;

  @override
  State<WeekdayBars> createState() => _WeekdayBarsState();
}

class _WeekdayBarsState extends State<WeekdayBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final max = widget.days.fold(0, (m, d) => math.max(m, d.inMilliseconds));
    var peak = 0;
    for (var i = 1; i < 7; i++) {
      if (widget.days[i] > widget.days[peak]) peak = i;
    }
    final selected = _selected ?? peak;

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label:
                        '${weekdayNames[i]}, ${listenedLabel(widget.days[i])}',
                    excludeSemantics: true,
                    onTap: () => setState(() => _selected = i),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: max == 0
                                ? 0.02
                                : math.max(
                                    0.02,
                                    widget.days[i].inMilliseconds / max,
                                  ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: widget.days[i] == Duration.zero
                                    ? colors.surfaceAlt
                                    : i == selected
                                    ? colors.foreground
                                    : colors.primary,
                                borderRadius: BorderRadius.circular(
                                  HaraRadius.sm,
                                ),
                                border: Border.all(
                                  color: colors.border,
                                  width: HaraBorder.thin,
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: HaraSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    weekdayLetters[i],
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium!.copyWith(
                      color: i == selected
                          ? colors.foreground
                          : colors.mutedForeground,
                    ),
                  ),
                ),
              ),
          ],
        ),
        ChartCaption(
          '${weekdayNames[selected]} · ${listenedLabel(widget.days[selected])}',
        ),
      ],
    );
  }
}

/// A calendar heatmap: one column per week (Monday on top), one cell per
/// day, darker for more listening. Tap a day for its total.
class ListeningHeatmap extends StatefulWidget {
  const ListeningHeatmap({
    super.key,
    required this.start,
    required this.weeks,
    required this.days,
    required this.today,
  });

  /// Monday of the first week (UTC midnight of the local date).
  final DateTime start;
  final int weeks;

  /// Listening per day (UTC midnight keys of local dates).
  final Map<DateTime, Duration> days;
  final DateTime today;

  @override
  State<ListeningHeatmap> createState() => _ListeningHeatmapState();
}

class _ListeningHeatmapState extends State<ListeningHeatmap> {
  late DateTime _selected = widget.today;

  static const _labelWidth = 18.0;
  static const _monthHeight = 18.0;

  DateTime _dayAt(int week, int weekday) =>
      widget.start.add(Duration(days: week * 7 + weekday));

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final activeDays = widget.days.values.where((d) => d > Duration.zero);
    final now = DateTime(widget.today.year, widget.today.month);

    return Semantics(
      label:
          'Listening calendar for the last ${widget.weeks} weeks: '
          '${activeDays.length} days with listening.',
      excludeSemantics: true,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cell = (constraints.maxWidth - _labelWidth) / widget.weeks;
              final height = _monthHeight + cell * 7;
              return GestureDetector(
                onTapUp: (details) {
                  final p = details.localPosition;
                  final week = ((p.dx - _labelWidth) / cell).floor();
                  final weekday = ((p.dy - _monthHeight) / cell).floor();
                  if (week < 0 ||
                      week >= widget.weeks ||
                      weekday < 0 ||
                      weekday > 6) {
                    return;
                  }
                  final day = _dayAt(week, weekday);
                  if (day.isAfter(widget.today)) return;
                  setState(() => _selected = day);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, height),
                  painter: _HeatmapPainter(
                    state: this,
                    cell: cell,
                    fill: colors.primary,
                    empty: colors.surfaceAlt,
                    stroke: colors.border,
                    label: textTheme.labelSmall!,
                  ),
                ),
              );
            },
          ),
          ChartCaption(
            '${formatDay(_selected, now)} · '
            '${listenedLabel(widget.days[_selected] ?? Duration.zero)}',
          ),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.state,
    required this.cell,
    required this.fill,
    required this.empty,
    required this.stroke,
    required this.label,
  });

  final _ListeningHeatmapState state;
  final double cell;
  final Color fill;
  final Color empty;
  final Color stroke;
  final TextStyle label;

  void _text(Canvas canvas, String text, Offset at) {
    TextPainter(
        text: TextSpan(text: text, style: label),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final widget = state.widget;
    final max = widget.days.values.fold(
      0,
      (m, d) => math.max(m, d.inMilliseconds),
    );
    const left = _ListeningHeatmapState._labelWidth;
    const top = _ListeningHeatmapState._monthHeight;
    final gap = math.max(1.5, cell * 0.14);

    for (final (row, letter) in [(0, 'M'), (2, 'W'), (4, 'F')]) {
      _text(canvas, letter, Offset(0, top + row * cell + cell * 0.1));
    }

    int? lastMonth;
    for (var week = 0; week < widget.weeks; week++) {
      final monday = state._dayAt(week, 0);
      if (monday.month != lastMonth) {
        // Label a month at its first full week, if there is room.
        if (lastMonth != null || monday.day <= 7) {
          _text(
            canvas,
            shortMonths[monday.month - 1],
            Offset(left + week * cell, 0),
          );
        }
        lastMonth = monday.month;
      }
      for (var weekday = 0; weekday < 7; weekday++) {
        final day = state._dayAt(week, weekday);
        if (day.isAfter(widget.today)) continue;
        final ms = (widget.days[day] ?? Duration.zero).inMilliseconds;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left + week * cell + gap / 2,
            top + weekday * cell + gap / 2,
            cell - gap,
            cell - gap,
          ),
          Radius.circular(cell * 0.2),
        );
        // Four strengths, relative to the busiest day.
        final level = ms == 0 || max == 0 ? 0 : (ms / max * 4).ceil();
        canvas.drawRRect(
          rect,
          Paint()
            ..color = level == 0
                ? empty
                : fill.withValues(
                    alpha: const <double>[0, 0.35, 0.6, 0.8, 1][level],
                  ),
        );
        if (day == state._selected || level == 4) {
          canvas.drawRRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = day == state._selected
                  ? HaraBorder.regular
                  : HaraBorder.thin * 0.7
              ..color = stroke,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => true;
}
