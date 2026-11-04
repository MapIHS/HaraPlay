import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/licenses.dart';
import 'core/artwork/artwork_cache.dart';
import 'core/artwork/artwork_files.dart';
import 'core/database/app_database.dart';
import 'core/debug/frame_stats.dart';
import 'core/debug/startup_trace.dart';
import 'core/platform/media_store_channel.dart';
import 'core/storage/preferences.dart';
import 'core/theme/system_tones.dart';
import 'features/audio_info/data/audio_info_repository.dart';
import 'features/audio_info/presentation/replay_gain_controller.dart';
import 'features/equalizer/presentation/equalizer_controller.dart';
import 'features/library/data/auto_rescan.dart';
import 'features/library/presentation/library_providers.dart';
import 'features/onboarding/data/media_permission_service.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/presentation/onboarding_controllers.dart';
import 'features/open_with/data/open_with.dart';
import 'features/player/data/hara_audio_handler.dart';
import 'features/player/data/just_audio_tail_player.dart';
import 'features/player/data/play_event_recorder.dart';
import 'features/player/data/player_audio.dart';
import 'features/player/presentation/crossfade_controller.dart';
import 'features/player/presentation/playback_speed.dart';
import 'features/player/presentation/player_providers.dart';
import 'features/player/presentation/stop_on_task_removed.dart';
import 'features/settings/presentation/color_choice_controller.dart';

/// Initialises app-wide services before the first frame: preferences, the
/// database, and the audio service that owns playback.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.start();
  registerAssetLicenses();
  StartupTrace.mark('binding');
  if (FrameStats.enabled) FrameStats.start();
  final channel = MediaStoreChannel();
  // Independent platform reads, side by side.
  final (preferences, (sdkInt, access), systemTones) = await (
    createPreferences(),
    // The permission check needs the SDK level; checked before the first
    // frame so the router starts on the right screen.
    channel.sdkIntWhenReady().then(
      (sdk) async => (sdk, await MediaPermissionService(sdkInt: sdk).check()),
    ),
    // Wallpaper colours (Android 12+), for the first frame.
    const SystemTonesChannel().read(),
  ).wait;
  StartupTrace.mark('preferences, permission, system tones');

  // Shared with the audio handler, which lives outside the widget tree.
  final database = AppDatabase.open();
  final artwork = ArtworkCache(
    channel,
    getApplicationCacheDirectory,
    files: LibraryArtworkFiles(database, channel),
  );
  // Header details and ReplayGain, for the player and the UI.
  final audioInfo = AudioInfoRepository(database.audioInfoDao);

  // Audio effects: none while the equalizer is disabled
  // (kEqualizerEnabled); then the players are plain just_audio players.
  final audio = await setUpPlayerAudio(preferences);
  StartupTrace.mark('database + effects');

  final handler = await AudioService.init(
    builder: () => HaraAudioHandler(
      // Unplayable queue entries are skipped by HaraAudioHandler itself.
      player: audio.mainPlayer(),
      recorder: PlayEventRecorder(database.playEventsDao),
      artwork: artwork,
      queueStore: database.queueStateDao,
      audioInfo: audioInfo,
      // Only made once crossfade is first used.
      tailPlayer: () => JustAudioTailPlayer(effects: audio.tailEffects()),
      // Overridable for device checks:
      // --dart-define=HARAPLAY_PAUSED_TIMEOUT_S=30
      // --dart-define=HARAPLAY_DETACH_AFTER_S=10
      releaseForeground: () async {
        try {
          await const MethodChannel('haraplay/playback')
              .invokeMethod<bool>('releaseForeground');
        } on PlatformException {
          // Best effort: the notification then stays until the app closes.
        }
      },
      detachForeground: () async {
        try {
          await const MethodChannel('haraplay/playback')
              .invokeMethod<bool>('detachForeground');
        } on PlatformException {
          // Best effort: the notification then stays until the timeout.
        }
      },
      detachAfter: const Duration(
        seconds: int.fromEnvironment(
          'HARAPLAY_DETACH_AFTER_S',
          defaultValue: 120,
        ),
      ),
      pausedTimeout: const Duration(
        seconds: int.fromEnvironment(
          'HARAPLAY_PAUSED_TIMEOUT_S',
          defaultValue: 600,
        ),
      ),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mmi.haraplay.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'Shows what is playing.',
      androidNotificationIcon: 'drawable/ic_stat_haraplay',
      // Stay in the foreground while paused: ColorOS hides a paused
      // notification from the lock screen otherwise. HaraAudioHandler
      // detaches it after 2 min paused (swipeable from then on) and stops
      // the service after 10 min (pausedTimeout).
      androidStopForegroundOnPause: false,
    ),
  );
  StartupTrace.mark('AudioService.init');
  await handler.configureSession();
  StartupTrace.mark('audio session');
  handler.setReplayGainMode(loadReplayGainMode(preferences));
  await handler.setSpeed(loadPlaybackSpeed(preferences));
  handler
    ..setCrossfade(loadCrossfade(preferences))
    ..setStopOnTaskRemoved(loadStopOnTaskRemoved(preferences));
  StartupTrace.mark('player settings');

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sdkIntProvider.overrideWithValue(sdkInt),
      initialMediaAccessProvider.overrideWithValue(access),
      mediaStoreChannelProvider.overrideWithValue(channel),
      appDatabaseProvider.overrideWithValue(database),
      artworkCacheProvider.overrideWithValue(artwork),
      playerProvider.overrideWithValue(handler),
      audioEffectsInfoProvider.overrideWithValue(audio.info),
      audioEffectsSinkProvider.overrideWithValue(audio.sink),
      audioInfoSourceProvider.overrideWithValue(audioInfo),
      initialSystemTonesProvider.overrideWithValue(systemTones),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const HaraPlayApp()),
  );
  StartupTrace.mark('runApp');

  // Everything else waits for the first frame, so the app shows up as soon
  // as possible. Without a screen (the engine can start for a media button)
  // there are no frames: then it starts after half a second.
  await Future.any([
    WidgetsBinding.instance.waitUntilFirstFrameRasterized,
    Future<void>.delayed(const Duration(milliseconds: 500)),
  ]);

  // Pick up files added or removed since the last launch. Onboarding runs
  // its own first sync; failures are kept in the controller's state.
  var started = false;
  void startLibrary() {
    if (started) return;
    started = true;
    // Last session's queue comes back paused, at the saved position.
    handler.restore().then((_) => StartupTrace.mark('queue restored')).ignore();
    // Rescan by itself when music files change while the app runs.
    container.read(autoRescanProvider);
    if (OnboardingRepository(preferences).readCompleted()) {
      container
          .read(librarySyncControllerProvider.notifier)
          .sync()
          .then((_) => StartupTrace.mark('library synced'))
          .ignore();
    }
  }

  if (access == MediaAccess.granted) {
    startLibrary();
  } else {
    // Access was revoked (or never given): once the user grants it again,
    // bring back the queue and rescan, as a normal launch would.
    container.listen(mediaAccessProvider, (_, next) {
      if (next == MediaAccess.granted) startLibrary();
    });
  }

  // Audio files opened with HaraPlay from other apps. Started last, so a
  // file opened at a cold start comes after the restored queue (it is
  // fetched from the platform when this starts listening).
  final opener = OpenWith(handler, DatabaseOpenWithLibrary(database));
  OpenWithChannel().files().listen((file) => opener.open(file).ignore());
}
