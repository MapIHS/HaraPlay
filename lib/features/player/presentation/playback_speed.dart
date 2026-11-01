import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_sheet.dart';
import 'player_providers.dart';

const _prefsKey = 'playback.speed';
const minSpeed = 0.5;
const maxSpeed = 2.0;

/// One-tap choices in the speed sheet.
const speedPresets = [0.75, 1.0, 1.25, 1.5, 2.0];

/// The saved speed (also applied at startup); 1 by default.
double loadPlaybackSpeed(SharedPreferencesWithCache prefs) =>
    (prefs.getDouble(_prefsKey) ?? 1).clamp(minSpeed, maxSpeed);

/// "1×", "1.25×", "0.5×".
String formatSpeed(double speed) {
  final rounded = (speed * 100).round() / 100;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toString();
  return '$text×';
}

/// The playback speed, remembered across launches.
class PlaybackSpeedController extends Notifier<double> {
  @override
  double build() => loadPlaybackSpeed(ref.watch(sharedPreferencesProvider));

  Future<void> set(double speed) async {
    // Steps of 0.05, so the slider and presets land on the same values.
    final value = ((speed * 20).round() / 20).clamp(minSpeed, maxSpeed);
    if (value == state) return;
    state = value;
    await ref.read(playerProvider).setSpeed(value);
    await ref.read(sharedPreferencesProvider).setDouble(_prefsKey, value);
  }
}

final playbackSpeedProvider = NotifierProvider<PlaybackSpeedController, double>(
  PlaybackSpeedController.new,
);

Future<void> showPlaybackSpeedSheet(BuildContext context) =>
    showHaraSheet<void>(
      context: context,
      title: 'Playback speed',
      builder: (_) => const _SpeedSheet(),
    );

class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playbackSpeedProvider);
    final controller = ref.read(playbackSpeedProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final colors = HaraColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatSpeed(speed),
            style: textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          Slider(
            value: speed,
            min: minSpeed,
            max: maxSpeed,
            divisions: ((maxSpeed - minSpeed) * 20).round(),
            label: formatSpeed(speed),
            semanticFormatterCallback: formatSpeed,
            onChanged: controller.set,
          ),
          const SizedBox(height: HaraSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: HaraSpacing.sm,
            runSpacing: HaraSpacing.sm,
            children: [
              for (final preset in speedPresets)
                Semantics(
                  selected: preset == speed,
                  child: HaraButton(
                    label: formatSpeed(preset),
                    size: HaraButtonSize.small,
                    variant: preset == speed
                        ? HaraButtonVariant.primary
                        : HaraButtonVariant.secondary,
                    onPressed: () => controller.set(preset),
                  ),
                ),
            ],
          ),
          const SizedBox(height: HaraSpacing.md),
          Text(
            'Applies to everything you play. The pitch stays the same.',
            style: textTheme.bodySmall!.copyWith(color: colors.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
