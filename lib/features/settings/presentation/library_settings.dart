import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/rescan.dart';
import '../data/settings_repository.dart';
import 'min_song_length_controller.dart';
import 'settings_tile.dart';

/// Settings → Library: rescan and the minimum song length.
class LibrarySettings extends ConsumerWidget {
  const LibrarySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(librarySyncControllerProvider).isLoading;
    final minLength = ref.watch(minSongLengthProvider);
    return Column(
      children: [
        SettingsTile(
          icon: HaraIcons.refreshCw,
          title: syncing ? 'Scanning…' : 'Rescan library',
          subtitle: 'Look for music added or removed on this phone',
          onTap: syncing ? null : () => rescanWithFeedback(context, ref),
        ),
        SettingsTile(
          icon: HaraIcons.timer,
          title: 'Hide short audio',
          subtitle: minLength == Duration.zero
              ? 'Off: every audio file is shown'
              : 'Hides files shorter than ${minLength.inSeconds} s',
          onTap: () => showHaraSheet<void>(
            context: context,
            title: 'Hide short audio',
            builder: (_) => const _MinLengthSheet(),
          ),
        ),
      ],
    );
  }
}

class _MinLengthSheet extends ConsumerWidget {
  const _MinLengthSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(minSongLengthProvider);
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HaraSpacing.gutter,
            0,
            HaraSpacing.gutter,
            HaraSpacing.sm,
          ),
          child: Text(
            'Ringtones, voice notes and other short clips stay on your '
            'phone, they are just left out of the library.',
            style: textTheme.bodyMedium!.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ),
        for (final option in SettingsRepository.minSongLengthOptions)
          Semantics(
            selected: option == current,
            inMutuallyExclusiveGroup: true,
            child: InkWell(
              onTap: () {
                ref.read(minSongLengthProvider.notifier).set(option);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HaraSpacing.gutter,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option == Duration.zero
                              ? 'Off'
                              : 'Shorter than ${option.inSeconds} seconds',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                      if (option == current)
                        Icon(HaraIcons.check, color: colors.foreground),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: HaraSpacing.lg),
      ],
    );
  }
}
