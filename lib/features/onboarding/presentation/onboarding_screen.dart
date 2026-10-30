import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/library_dao.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/platform/media_store_channel.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_chip.dart';
import '../../../core/widgets/hara_pressable.dart';
import '../../library/data/library_sync_service.dart';
import '../../settings/presentation/min_song_length_controller.dart';
import '../data/media_permission_service.dart';
import 'onboarding_controllers.dart';

/// First sync into the database, then the counts the user will see.
final firstScanProvider = FutureProvider.autoDispose<LibraryCounts>((
  ref,
) async {
  // The service, not the controller: a provider may not change another
  // provider's state while it is being built.
  await ref.read(librarySyncServiceProvider).sync();
  return ref
      .read(libraryDaoProvider)
      .counts(minDurationMs: ref.read(minSongLengthProvider).inMilliseconds);
});

/// Permission gate and first scan. The router keeps the user here until
/// access is granted and they have seen the scan result.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _asked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Picks up a grant made in system settings.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(mediaAccessProvider.notifier).recheck(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    await ref.read(mediaAccessProvider.notifier).request();
    if (mounted) {
      setState(() {
        _busy = false;
        _asked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(mediaAccessProvider);
    // No app bar here, so apply the themed system-bar style directly.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle!,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(HaraSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - HaraSpacing.xl * 2,
                ),
                child: switch (access) {
                  MediaAccess.granted => const _ScanStep(),
                  MediaAccess.denied => _AccessStep(
                    showDeniedNote: _asked,
                    busy: _busy,
                    onAllow: _request,
                  ),
                  MediaAccess.permanentlyDenied => _BlockedStep(
                    sdkInt: ref.watch(sdkIntProvider),
                    onOpenSettings: () =>
                        ref.read(mediaAccessProvider.notifier).openSettings(),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared layout: icon tile, headline, body, optional note, actions at the
/// bottom.
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.note,
    this.tileColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? note;
  final List<Widget> actions;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: HaraSpacing.xxl),
            HaraPressable(
              color: tileColor ?? colors.primary,
              borderRadius: HaraRadius.lg,
              isButton: false,
              child: SizedBox.square(
                dimension: 72,
                child: Icon(icon, size: 32, color: colors.onPrimary),
              ),
            ),
            const SizedBox(height: HaraSpacing.xl),
            Semantics(
              header: true,
              child: Text(title, style: textTheme.displaySmall),
            ),
            const SizedBox(height: HaraSpacing.md),
            Text(
              message,
              style: textTheme.bodyLarge!.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: HaraSpacing.xl),
              note!,
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: HaraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) const SizedBox(height: HaraSpacing.sm),
                action,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A bordered callout with a tinted fill.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return Container(
      padding: const EdgeInsets.all(HaraSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? colors.surfaceAlt,
        borderRadius: BorderRadius.circular(HaraRadius.md),
        border: Border.all(color: colors.border, width: HaraBorder.thin),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: HaraSizes.iconSmall, color: colors.foreground),
          const SizedBox(width: HaraSpacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _AccessStep extends StatelessWidget {
  const _AccessStep({
    required this.showDeniedNote,
    required this.busy,
    required this.onAllow,
  });

  final bool showDeniedNote;
  final bool busy;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      icon: HaraIcons.audioLines,
      title: "Let's find your music",
      message:
          'HaraPlay plays the audio files stored on this phone, so it needs '
          'permission to read them. Nothing leaves your device: HaraPlay has '
          'no internet access.',
      note: showDeniedNote
          ? _Note(
              icon: HaraIcons.circleAlert,
              color: HaraColors.of(context).coral,
              text:
                  "Without access HaraPlay can't show your songs. You can "
                  'allow it whenever you are ready.',
            )
          : null,
      actions: [
        HaraButton(
          label: 'Allow access to music',
          icon: HaraIcons.folderOpen,
          expand: true,
          onPressed: busy ? null : onAllow,
        ),
      ],
    );
  }
}

class _BlockedStep extends StatelessWidget {
  const _BlockedStep({required this.sdkInt, required this.onOpenSettings});

  final int sdkInt;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // The permission's name and control differ between Android versions.
    final steps = switch (sdkInt) {
      >= 33 => 'tap Permissions, then Music and audio, and choose Allow',
      >= 30 => 'tap Permissions, then Files and media, and choose Allow',
      _ => 'tap Permissions and turn on Storage',
    };
    return _StepLayout(
      icon: HaraIcons.circleAlert,
      tileColor: HaraColors.of(context).coral,
      title: 'Music access is off',
      message:
          "Android won't ask again, so access has to be turned on in "
          'settings.',
      note: _Note(
        icon: HaraIcons.info,
        text: 'Open settings, $steps. HaraPlay continues when you come back.',
      ),
      actions: [
        HaraButton(
          label: 'Open settings',
          icon: HaraIcons.settings,
          expand: true,
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}

class _ScanStep extends ConsumerWidget {
  const _ScanStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(firstScanProvider);
    // Access may have been granted in system settings, so the notification
    // prompt is tied to finishing onboarding rather than to the access request.
    Future<void> finish() async {
      await ref.read(mediaPermissionServiceProvider).requestNotifications();
      await ref.read(onboardingCompletedProvider.notifier).complete();
    }

    void rescan() => ref.invalidate(firstScanProvider);

    return switch (scan) {
      AsyncData(value: final summary) when summary.songs > 0 => _StepLayout(
        icon: HaraIcons.check,
        tileColor: HaraColors.of(context).mint,
        title: _songsFound(summary.songs),
        message: 'Your library is ready.',
        note: Wrap(
          spacing: HaraSpacing.sm,
          runSpacing: HaraSpacing.sm,
          children: [
            HaraChip(
              value: '${summary.albums}',
              label: summary.albums == 1 ? 'Album' : 'Albums',
            ),
            HaraChip(
              value: '${summary.folders}',
              label: summary.folders == 1 ? 'Folder' : 'Folders',
            ),
          ],
        ),
        actions: [
          HaraButton(
            label: 'Start listening',
            icon: HaraIcons.play,
            expand: true,
            onPressed: finish,
          ),
        ],
      ),
      AsyncData() => _StepLayout(
        icon: HaraIcons.music,
        title: 'No music found yet',
        message:
            'HaraPlay looks for audio files on this phone. Copy some music '
            'into the Music folder, then scan again.',
        actions: [
          HaraButton(
            label: 'Scan again',
            icon: HaraIcons.refreshCw,
            expand: true,
            onPressed: rescan,
          ),
          HaraButton(
            label: 'Continue anyway',
            variant: HaraButtonVariant.ghost,
            expand: true,
            onPressed: finish,
          ),
        ],
      ),
      AsyncError() => _StepLayout(
        icon: HaraIcons.circleAlert,
        tileColor: HaraColors.of(context).coral,
        title: "Couldn't read your music",
        message: 'Something went wrong while scanning. Please try again.',
        actions: [
          HaraButton(
            label: 'Try again',
            icon: HaraIcons.refreshCw,
            expand: true,
            onPressed: rescan,
          ),
        ],
      ),
      AsyncLoading() => const _StepLayout(
        icon: HaraIcons.search,
        title: 'Looking for music…',
        message: 'Scanning the audio files on this phone.',
        note: LinearProgressIndicator(),
        actions: [],
      ),
    };
  }

  static String _songsFound(int count) =>
      count == 1 ? 'Found 1 song' : 'Found $count songs';
}
