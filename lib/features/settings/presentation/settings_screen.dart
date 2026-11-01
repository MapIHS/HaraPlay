import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../audio_info/domain/audio_info.dart';
import '../../audio_info/presentation/replay_gain_controller.dart';
import '../../equalizer/presentation/equalizer_controller.dart';
import '../../equalizer/presentation/equalizer_screen.dart';
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
          const SectionHeader(title: 'Library'),
          const LibrarySettings(),
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
  Widget build(BuildContext context, WidgetRef ref) => SettingsTile(
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
