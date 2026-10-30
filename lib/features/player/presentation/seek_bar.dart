import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import 'player_providers.dart';

/// Seek slider with elapsed and remaining time. While dragging, the slider
/// follows the finger; the player seeks once on release.
class SeekBar extends ConsumerStatefulWidget {
  const SeekBar({super.key, required this.duration});

  final Duration duration;

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final totalMs = widget.duration.inMilliseconds;
    final playedMs = _dragging ?? position.inMilliseconds.toDouble();
    final value = totalMs <= 0 ? 0.0 : (playedMs / totalMs).clamp(0.0, 1.0);
    final shown = Duration(milliseconds: (value * totalMs).round());
    final mono = HaraTextStyles.of(context).mono;

    return Column(
      children: [
        Slider(
          value: value,
          label: formatDuration(shown),
          semanticFormatterCallback: (v) =>
              '${formatDuration(Duration(milliseconds: (v * totalMs).round()))}'
              ' of ${formatDuration(widget.duration)}',
          onChanged: totalMs <= 0
              ? null
              : (v) => setState(() => _dragging = v * totalMs),
          onChangeEnd: totalMs <= 0
              ? null
              : (v) {
                  ref
                      .read(playerProvider)
                      .seek(Duration(milliseconds: (v * totalMs).round()));
                  setState(() => _dragging = null);
                },
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

/// "-0:30" for 15 s into 45 s. Elapsed time rounds down, so remaining time
/// rounds up, and the two always add up to the length.
String remainingLabel(Duration elapsed, Duration total) {
  final remainingMs = (total - elapsed).inMilliseconds.clamp(0, 1 << 62);
  return '-${formatDuration(Duration(seconds: (remainingMs / 1000).ceil()))}';
}
