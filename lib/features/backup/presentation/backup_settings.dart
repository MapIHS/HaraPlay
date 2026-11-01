import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_dialog_actions.dart';
import '../../audio_info/presentation/replay_gain_controller.dart';
import '../../equalizer/presentation/equalizer_controller.dart';
import '../../library/data/library_sync_service.dart';
import '../../library/presentation/library_providers.dart';
import '../../player/presentation/crossfade_controller.dart';
import '../../player/presentation/playback_speed.dart';
import '../../player/presentation/player_providers.dart';
import '../../settings/presentation/color_choice_controller.dart';
import '../../settings/presentation/excluded_folders_controller.dart';
import '../../settings/presentation/min_song_length_controller.dart';
import '../../settings/presentation/settings_tile.dart';
import '../../settings/presentation/theme_mode_controller.dart';
import '../data/backup_service.dart';
import '../domain/backup.dart';

/// Settings › Your data: back up and restore likes, playlists, play
/// history and settings.
class BackupSettings extends ConsumerWidget {
  const BackupSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      SettingsTile(
        icon: HaraIcons.fileOutput,
        title: 'Back up',
        subtitle: 'Likes, playlists, play history and settings, in one file',
        onTap: () => _backUp(context, ref),
      ),
      SettingsTile(
        icon: HaraIcons.fileInput,
        title: 'Restore from a backup',
        subtitle: "Adds what's in the file; nothing here is removed",
        onTap: () => _restore(context, ref),
      ),
    ],
  );

  Future<void> _backUp(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    String? message;
    try {
      final result = await ref.read(backupServiceProvider).export();
      if (result != null) {
        final (name, backup) = result;
        message = 'Saved "$name": ${backupContents(backup)}.';
      }
    } on Object {
      message = "Couldn't save the backup. Please try again.";
    }
    if (message == null) return; // Cancelled.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    final service = ref.read(backupServiceProvider);
    final Backup? backup;
    try {
      backup = await service.pick();
    } on FormatException catch (e) {
      say(
        e.message == 'Made by a newer HaraPlay'
            ? 'This backup was made by a newer HaraPlay. Update the app first.'
            : "That file isn't a HaraPlay backup.",
      );
      return;
    } on Object {
      say("Couldn't read that file. Please try again.");
      return;
    }
    if (backup == null || !context.mounted) return;

    final withSettings = await _confirm(context, backup);
    if (withSettings == null || !context.mounted) return;
    final RestoreReport report;
    try {
      report = await service.restore(backup, settings: withSettings);
    } on Object {
      say("Couldn't restore the backup. Nothing was changed.");
      return;
    }
    if (report.settingsRestored) await reloadSettings(ref);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Backup restored'),
        content: Text(describeRestore(report)),
        actionsPadding: HaraDialogActions.padding,
        actions: [
          // Our own button: a plain TextButton draws saffron text, which
          // is too faint on white.
          HaraButton(
            label: 'OK',
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// True / false: restore with / without settings; null: cancelled.
  Future<bool?> _confirm(BuildContext context, Backup backup) =>
      showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (context) => _ConfirmRestore(backup: backup),
      );
}

class _ConfirmRestore extends StatefulWidget {
  const _ConfirmRestore({required this.backup});

  final Backup backup;

  @override
  State<_ConfirmRestore> createState() => _ConfirmRestoreState();
}

class _ConfirmRestoreState extends State<_ConfirmRestore> {
  late bool _settings = widget.backup.settings.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final backup = widget.backup;
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(backup.createdAt.toLocal());
    return AlertDialog(
      title: const Text('Restore backup?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('From $date: ${backupContents(backup)}.'),
          const SizedBox(height: HaraSpacing.sm),
          Text(
            "It's added to what's already here; nothing is removed or "
            'replaced.',
            style: textTheme.bodySmall!.copyWith(color: colors.mutedForeground),
          ),
          if (backup.settings.isNotEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _settings,
              onChanged: (v) => setState(() => _settings = v ?? false),
              title: const Text('Also restore settings'),
              subtitle: const Text('Colours, equalizer, playback, library'),
            ),
        ],
      ),
      actionsPadding: HaraDialogActions.padding,
      actions: [
        HaraDialogActions(
          confirmLabel: 'Restore',
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () => Navigator.of(context).pop(_settings),
        ),
      ],
    );
  }
}

/// "12 likes, 3 playlists and 845 plays".
String backupContents(Backup backup) {
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  return '${count(backup.likes.length, 'like', 'likes')}, '
      '${count(backup.playlists.length, 'playlist', 'playlists')} and '
      '${count(backup.plays.length, 'play', 'plays')}';
}

/// The restore's outcome, one line per kind.
String describeRestore(RestoreReport r) {
  String part(int added, int kept, String noun) {
    final already = kept == 0 ? '' : ' ($kept already here)';
    return '$noun: $added added$already';
  }

  return [
    part(r.likesAdded, r.likesKept, 'Likes'),
    part(r.playlistsAdded, r.playlistsKept, 'Playlists'),
    part(r.playsAdded, r.playsKept, 'Plays'),
    if (r.settingsRestored) 'Settings restored',
    if (r.missingSongs > 0)
      '${r.missingSongs == 1 ? '1 song' : '${r.missingSongs} songs'} from '
          "the backup aren't on this phone. Their plays still count in your "
          "stats; likes and playlist entries of them couldn't be added.",
  ].join('\n');
}

/// After settings were restored into preferences: rebuild the settings
/// and hand them to the player, the effects and the library.
Future<void> reloadSettings(WidgetRef ref) async {
  for (final provider in [
    themeModeProvider,
    colorChoiceProvider,
    minSongLengthProvider,
    excludedFoldersProvider,
    replayGainProvider,
    playbackSpeedProvider,
    crossfadeProvider,
    equalizerProvider,
    songSortProvider,
    albumSortProvider,
    artistSortProvider,
    folderSortProvider,
    genreSortProvider,
  ]) {
    ref.invalidate(provider);
  }
  final player = ref.read(playerProvider);
  player
    ..setReplayGainMode(ref.read(replayGainProvider))
    ..setCrossfade(ref.read(crossfadeProvider));
  await player.setSpeed(ref.read(playbackSpeedProvider));
  await applyEqualizerSettings(
    ref.read(equalizerProvider),
    ref.read(audioEffectsInfoProvider),
    ref.read(audioEffectsSinkProvider),
  );
  await ref
      .read(libraryDaoProvider)
      .applyExclusions(ref.read(excludedFoldersProvider));
}
