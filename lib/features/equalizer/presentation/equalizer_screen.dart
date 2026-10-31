import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_card.dart';
import '../../../core/widgets/hara_pills.dart';
import '../domain/equalizer.dart';
import 'equalizer_controller.dart';

/// "Off", "Bass boost", "Custom · Loudness +4 dB" (Settings subtitle).
String equalizerSummary(EqualizerSettings s, AudioEffectsInfo info) {
  if (info.equalizer == null && !info.loudness) return 'Not available';
  final parts = [
    if (s.enabled && info.equalizer != null)
      s.presetId == customPresetId
          ? 'Custom'
          : eqPresets.firstWhere((p) => p.id == s.presetId).label,
    if (info.loudness && s.loudnessDb > 0)
      'Loudness ${formatGain(s.loudnessDb)}',
  ];
  return parts.isEmpty ? 'Off' : parts.join(' · ');
}

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(audioEffectsInfoProvider);
    final settings = ref.watch(equalizerProvider);
    final controller = ref.read(equalizerProvider.notifier);
    final available = info.equalizer != null || info.loudness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          if (available)
            HaraButton(
              label: 'Reset',
              variant: HaraButtonVariant.ghost,
              size: HaraButtonSize.small,
              onPressed: controller.reset,
            ),
          const SizedBox(width: HaraSpacing.xs),
        ],
      ),
      body: !available
          ? const EmptyState(
              icon: HaraIcons.slidersHorizontal,
              title: 'No equalizer on this phone',
              message:
                  "This phone doesn't offer audio effects to apps. Its own "
                  'sound settings may still have one.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                HaraSpacing.gutter,
                HaraSpacing.sm,
                HaraSpacing.gutter,
                HaraSpacing.xxxl,
              ),
              children: [
                if (info.equalizer case final layout?)
                  _EqualizerCard(layout: layout, settings: settings)
                else
                  const _Note(
                    'This phone has no equalizer for apps; only the '
                    'loudness boost is available.',
                  ),
                if (info.loudness) ...[
                  const SizedBox(height: HaraSpacing.lg),
                  _LoudnessCard(settings: settings),
                ],
                const SizedBox(height: HaraSpacing.lg),
                const _Note(
                  "Your phone's own sound effect (on ColorOS: Dirac / Real "
                  'Original Sound, in the Sound settings) is applied after '
                  'these, to everything the phone plays. Turn it off to hear '
                  'the equalizer exactly as set.',
                ),
              ],
            ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          HaraIcons.info,
          size: HaraSizes.iconSmall,
          color: colors.mutedForeground,
        ),
        const SizedBox(width: HaraSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _EqualizerCard extends ConsumerWidget {
  const _EqualizerCard({required this.layout, required this.settings});

  final EqualizerLayout layout;
  final EqualizerSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(equalizerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final gains = settings.gainsFor(layout);
    final hasCustom =
        settings.presetId == customPresetId || settings.customGains.isNotEmpty;
    final presetIds = [
      for (final p in eqPresets) p.id,
      if (hasCustom) customPresetId,
    ];

    return HaraCard(
      padding: const EdgeInsets.symmetric(vertical: HaraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: HaraSpacing.lg,
              right: HaraSpacing.sm,
            ),
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text('Equalizer', style: textTheme.titleLarge),
                  ),
                  Switch(
                    value: settings.enabled,
                    onChanged: controller.setEnabled,
                  ),
                ],
              ),
            ),
          ),
          HaraPillChoice<String>(
            values: presetIds,
            selected: settings.presetId,
            label: (id) => id == customPresetId
                ? 'Custom'
                : eqPresets.firstWhere((p) => p.id == id).label,
            onChanged: controller.selectPreset,
          ),
          const SizedBox(height: HaraSpacing.sm),
          // Dimmed while off; moving a band switches it on.
          Opacity(
            opacity: settings.enabled ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.sm),
              child: Row(
                children: [
                  for (var i = 0; i < layout.bands.length; i++)
                    Expanded(
                      child: _BandSlider(
                        frequency: layout.bands[i],
                        gain: gains[i],
                        min: layout.minDecibels,
                        max: layout.maxDecibels,
                        onChanged: (g) => controller.setBandGain(i, g),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One band: its gain on top, a vertical slider, its frequency below.
class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.frequency,
    required this.gain,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double frequency;
  final double gain;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final mono = HaraTextStyles.of(context).mono;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(formatGain(gain), style: mono),
        ),
        SizedBox(
          height: 200,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: gain.clamp(min, max),
              min: min,
              max: max,
              // Half-decibel steps.
              divisions: ((max - min) * 2).round().clamp(1, 1000),
              label: formatGain(gain),
              semanticFormatterCallback: (v) =>
                  '${formatFrequency(frequency)}, ${formatGain(v)}',
              onChanged: onChanged,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatFrequency(frequency),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _LoudnessCard extends ConsumerWidget {
  const _LoudnessCard({required this.settings});

  final EqualizerSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final db = settings.loudnessDb;
    String label(double v) => v == 0 ? 'Off' : formatGain(v);
    return HaraCard(
      padding: const EdgeInsets.fromLTRB(
        HaraSpacing.lg,
        HaraSpacing.md,
        HaraSpacing.sm,
        HaraSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Loudness boost', style: textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.only(right: HaraSpacing.sm),
                child: Text(
                  label(db),
                  style: HaraTextStyles.of(context).monoStrong,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: HaraSpacing.sm),
            child: Text(
              'Makes quiet songs louder. High values can distort.',
              style: textTheme.bodySmall,
            ),
          ),
          Slider(
            value: db,
            max: EqualizerSettings.maxLoudnessDb,
            divisions: (EqualizerSettings.maxLoudnessDb * 2).round(),
            label: label(db),
            semanticFormatterCallback: (v) => 'Loudness boost ${label(v)}',
            onChanged: ref.read(equalizerProvider.notifier).setLoudness,
          ),
        ],
      ),
    );
  }
}
