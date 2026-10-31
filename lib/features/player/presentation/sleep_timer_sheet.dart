import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_dialog_actions.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../../core/widgets/hara_pressable.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../domain/sleep_timer_state.dart';
import 'player_providers.dart';

/// Preset lengths offered in the sleep timer sheet.
const sleepTimerPresets = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(hours: 1),
];

/// "15 minutes", "1 hour", "1 h 30 min".
String sleepTimerLabel(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return minutes == 1 ? '1 minute' : '$minutes minutes';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return hours == 1 ? '1 hour' : '$hours hours';
  return '$hours h $rest min';
}

Future<void> showSleepTimerSheet(BuildContext context) => showHaraSheet<void>(
  context: context,
  title: 'Sleep timer',
  builder: (_) => const _SleepTimerSheet(),
);

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepTimerProvider).value ?? const SleepTimerOff();
    final player = ref.read(playerProvider);
    void done() => Navigator.of(context).pop();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.active)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              0,
              HaraSpacing.gutter,
              HaraSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Countdown(
                    state: state,
                    builder: (text) => Text(
                      text,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    long: true,
                  ),
                ),
                HaraButton(
                  label: 'Turn off',
                  variant: HaraButtonVariant.secondary,
                  size: HaraButtonSize.small,
                  onPressed: () {
                    player.cancelSleepTimer();
                    done();
                  },
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              0,
              HaraSpacing.gutter,
              HaraSpacing.sm,
            ),
            child: Text(
              'Music fades out over 10 seconds, then pauses.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Divider(),
        for (final preset in sleepTimerPresets)
          _OptionRow(
            icon: HaraIcons.timer,
            label: sleepTimerLabel(preset),
            onTap: () {
              player.startSleepTimer(preset);
              done();
            },
          ),
        _OptionRow(
          icon: HaraIcons.music,
          label: 'End of this song',
          selected: state is SleepAtEndOfTrack,
          onTap: () {
            player.sleepAtEndOfTrack();
            done();
          },
        ),
        _OptionRow(
          icon: HaraIcons.slidersHorizontal,
          label: 'Custom…',
          onTap: () async {
            final duration = await showCustomSleepTimerDialog(context);
            if (duration == null) return;
            player.startSleepTimer(duration);
            if (context.mounted) done();
          },
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.gutter),
            child: Row(
              children: [
                Icon(icon, size: HaraSizes.iconSmall),
                const SizedBox(width: HaraSpacing.lg),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (selected)
                  Icon(
                    HaraIcons.check,
                    size: HaraSizes.iconSmall,
                    color: colors.emphasis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a length from 5 minutes to 3 hours.
Future<Duration?> showCustomSleepTimerDialog(BuildContext context) =>
    showDialog<Duration>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const _CustomDialog(),
    );

class _CustomDialog extends StatefulWidget {
  const _CustomDialog();

  @override
  State<_CustomDialog> createState() => _CustomDialogState();
}

class _CustomDialogState extends State<_CustomDialog> {
  static const _min = 5;
  static const _max = 180;
  int _minutes = 20;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(minutes: _minutes);
    return AlertDialog(
      title: const Text('Sleep timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sleepTimerLabel(duration),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: HaraSpacing.sm),
          Slider(
            value: _minutes.toDouble(),
            min: _min.toDouble(),
            max: _max.toDouble(),
            divisions: (_max - _min) ~/ 5,
            label: sleepTimerLabel(duration),
            semanticFormatterCallback: (v) =>
                sleepTimerLabel(Duration(minutes: v.round())),
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),
        ],
      ),
      actionsPadding: HaraDialogActions.padding,
      actions: [
        HaraDialogActions(
          confirmLabel: 'Start',
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () => Navigator.of(context).pop(duration),
        ),
      ],
    );
  }
}

/// Rebuilds once a second while a countdown runs, with the time left.
class _Countdown extends StatefulWidget {
  const _Countdown({
    required this.state,
    required this.builder,
    this.long = false,
  });

  final SleepTimerState state;
  final Widget Function(String text) builder;

  /// "Stops in 12:34" instead of "12:34".
  final bool long;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Countdown old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.state is SleepCountdown) {
      _tick ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    sleepTimerText(widget.state, clock.now(), long: widget.long),
  );
}

/// The countdown text: "12:34" / "End of song", or with [long]
/// "Stops in 12:34" / "Stops after this song".
String sleepTimerText(
  SleepTimerState state,
  DateTime now, {
  bool long = false,
}) => switch (state) {
  SleepCountdown() => () {
    // Round up, so the last second shows 0:01 rather than 0:00.
    final left = state.remainingAt(now);
    final shown = Duration(seconds: (left.inMilliseconds / 1000).ceil());
    return long ? 'Stops in ${formatDuration(shown)}' : formatDuration(shown);
  }(),
  SleepAtEndOfTrack() => long ? 'Stops after this song' : 'End of song',
  SleepTimerOff() => '',
};

/// Now Playing's sleep timer control: a moon button, or while a timer runs
/// a chip with the time left. Opens the sleep timer sheet.
class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepTimerProvider).value ?? const SleepTimerOff();
    void open() => showSleepTimerSheet(context);
    if (!state.active) {
      return HaraIconButton(
        icon: HaraIcons.moon,
        tooltip: 'Sleep timer',
        onPressed: open,
      );
    }
    final colors = HaraColors.of(context);
    return _Countdown(
      state: state,
      builder: (text) => Semantics(
        button: true,
        label: 'Sleep timer: ${sleepTimerText(state, clock.now(), long: true)}',
        excludeSemantics: true,
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: HaraSizes.minTouchTarget,
          ),
          // widthFactor 1: as wide as the chip, not the whole row.
          child: Center(
            widthFactor: 1,
            child: HaraPressable(
              onPressed: open,
              color: colors.primary,
              borderRadius: HaraRadius.pill,
              borderWidth: HaraBorder.thin,
              shadowOffset: HaraShadow.small,
              padding: const EdgeInsets.symmetric(
                horizontal: HaraSpacing.md,
                vertical: HaraSpacing.xs + 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(HaraIcons.moon, size: 16, color: colors.onPrimary),
                  const SizedBox(width: HaraSpacing.xs + 2),
                  Flexible(
                    child: Text(
                      text,
                      style: HaraTextStyles.of(context).monoStrong
                          .copyWith(color: colors.onPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
