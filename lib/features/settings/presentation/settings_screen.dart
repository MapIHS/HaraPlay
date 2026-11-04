import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/features.dart';
import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../audio_info/domain/audio_info.dart';
import '../../audio_info/presentation/replay_gain_controller.dart';
import '../../backup/presentation/backup_settings.dart';
import '../../equalizer/presentation/equalizer_controller.dart';
import '../../equalizer/presentation/equalizer_screen.dart';
import '../../player/presentation/crossfade_controller.dart';
import '../../player/presentation/stop_on_task_removed.dart';
import 'choice_sheet.dart';
import 'color_choice_picker.dart';
import 'library_settings.dart';
import 'settings_tile.dart';
import 'theme_mode_picker.dart';

/// Settings, opened from Home's app bar above the tab shell.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
        children: [
          const SectionHeader(title: 'Appearance'),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              HaraSpacing.sm,
              HaraSpacing.gutter,
              HaraSpacing.lg,
            ),
            child: ThemeModePicker(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              0,
              HaraSpacing.gutter,
              HaraSpacing.lg,
            ),
            child: ColorChoicePicker(),
          ),
          const SectionHeader(title: 'Playback'),
          const _EqualizerTile(),
          const _ReplayGainTile(),
          const _CrossfadeTiles(),
          const _StopOnTaskRemovedTile(),
          const SectionHeader(title: 'Library'),
          const LibrarySettings(),
          const SectionHeader(title: 'Your data'),
          const BackupSettings(),
          const SectionHeader(title: 'About'),
          SettingsTile(
            icon: HaraIcons.info,
            title: 'Open-source licenses',
            subtitle: 'Fonts, icons and libraries used by HaraPlay',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'HaraPlay',
              applicationLegalese: 'MIT License\n© 2026 The HaraPlay Authors',
            ),
          ),
          if (kDebugMode) ...[
            const SectionHeader(title: 'Developer'),
            SettingsTile(
              icon: HaraIcons.slidersHorizontal,
              title: 'Design gallery',
              subtitle: 'Debug builds only',
              onTap: () => context.push(AppRoutes.designGallery),
            ),
            SettingsTile(
              icon: HaraIcons.folder,
              title: 'MediaStore inspector',
              subtitle: 'Every song and tag the library scan reads',
              onTap: () => context.push(AppRoutes.mediaStoreDebug),
            ),
            SettingsTile(
              icon: HaraIcons.chartColumn,
              title: 'Library database',
              subtitle: 'Table counts, last sync and tag fallbacks',
              onTap: () => context.push(AppRoutes.libraryDatabaseDebug),
            ),
          ],
        ],
      ),
    );
  }
}

class _EqualizerTile extends ConsumerWidget {
  const _EqualizerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      // Hidden while the equalizer is disabled (kEqualizerEnabled).
      !ref.watch(equalizerEnabledProvider)
      ? const SizedBox.shrink()
      : SettingsTile(
          icon: HaraIcons.slidersHorizontal,
          title: 'Equalizer',
          subtitle: equalizerSummary(
            ref.watch(equalizerProvider),
            ref.watch(audioEffectsInfoProvider),
          ),
          onTap: () => context.push(AppRoutes.equalizer),
        );
}

class _ReplayGainTile extends ConsumerWidget {
  const _ReplayGainTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(replayGainProvider);
    return SettingsTile(
      icon: HaraIcons.audioLines,
      title: 'ReplayGain',
      subtitle: mode == ReplayGainMode.off
          ? 'Off'
          : '${mode.label} · ${replayGainDescription(mode)}',
      onTap: () => showHaraSheet<void>(
        context: context,
        title: 'ReplayGain',
        builder: (_) => const _ReplayGainSheet(),
      ),
    );
  }
}

class _ReplayGainSheet extends ConsumerWidget {
  const _ReplayGainSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ChoiceSheet<ReplayGainMode>(
        intro:
            'Evens out the volume between songs, using the ReplayGain '
            'tags your music files may have. Songs are only made quieter, '
            'never louder; songs without tags are left alone.',
        options: ReplayGainMode.values,
        selected: ref.watch(replayGainProvider),
        label: (mode) => mode.label,
        description: replayGainDescription,
        onSelected: ref.read(replayGainProvider.notifier).set,
      );
}

class _CrossfadeTiles extends ConsumerWidget {
  const _CrossfadeTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(crossfadeProvider);
    final controller = ref.read(crossfadeProvider.notifier);
    final seconds = settings.length.inSeconds;
    return Column(
      children: [
        SettingsTile(
          icon: HaraIcons.blend,
          title: 'Crossfade',
          subtitle: seconds == 0
              ? 'Off: songs follow each other gaplessly'
              : '${crossfadeLabel(seconds)} · Songs blend into each other',
          onTap: () => showHaraSheet<void>(
            context: context,
            title: 'Crossfade',
            builder: (_) => ChoiceSheet<int>(
              intro:
                  'The end of a song fades out while the next one fades in. '
                  'Tracks of the same album played in order (with real album '
                  'tags and track numbers) stay gapless.',
              options: crossfadeChoices,
              selected: seconds,
              label: crossfadeLabel,
              onSelected: controller.setLength,
            ),
          ),
        ),
        if (seconds > 0)
          MergeSemantics(
            child: SettingsTile(
              icon: HaraIcons.skipForward,
              title: 'Crossfade when skipping',
              subtitle: settings.onSkip
                  ? 'Skipping to the next song fades too'
                  : 'Skipping cuts straight to the next song',
              onTap: () => controller.setOnSkip(!settings.onSkip),
              trailing: Switch(
                value: settings.onSkip,
                onChanged: controller.setOnSkip,
              ),
            ),
          ),
      ],
    );
  }
}

class _StopOnTaskRemovedTile extends ConsumerWidget {
  const _StopOnTaskRemovedTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stop = ref.watch(stopOnTaskRemovedProvider);
    final controller = ref.read(stopOnTaskRemovedProvider.notifier);
    return MergeSemantics(
      child: SettingsTile(
        icon: HaraIcons.x,
        title: 'Stop when removed from Recent apps',
        subtitle: stop
            ? 'Swiping HaraPlay away stops the music'
            : 'Music keeps playing; a paused player always closes',
        onTap: () => controller.set(!stop),
        trailing: Switch(value: stop, onChanged: controller.set),
      ),
    );
  }
}
