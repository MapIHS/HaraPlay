import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/licenses.dart';
import 'core/artwork/artwork_cache.dart';
import 'core/database/app_database.dart';
import 'core/debug/frame_stats.dart';
import 'core/platform/media_store_channel.dart';
import 'core/storage/preferences.dart';
import 'core/theme/system_tones.dart';
import 'features/audio_info/data/audio_info_repository.dart';
import 'features/audio_info/presentation/replay_gain_controller.dart';
import 'features/equalizer/data/audio_effects.dart';
import 'features/equalizer/presentation/equalizer_controller.dart';
import 'features/library/presentation/library_providers.dart';
import 'features/onboarding/data/media_permission_service.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/presentation/onboarding_controllers.dart';
import 'features/player/data/hara_audio_handler.dart';
import 'features/player/data/play_event_recorder.dart';
import 'features/player/presentation/player_providers.dart';
import 'features/settings/presentation/color_choice_controller.dart';

/// Initialises app-wide services before the first frame: preferences, the
/// database, and the audio service that owns playback.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  if (FrameStats.enabled) FrameStats.start();
  final preferences = await createPreferences();
  final channel = MediaStoreChannel();
  final sdkInt = await channel.sdkIntWhenReady();
  // Checked before the first frame so the router starts on the right screen.
  final access = await MediaPermissionService(sdkInt: sdkInt).check();

  // Wallpaper colours (Android 12+), for the first frame.
  final systemTones = await const SystemTonesChannel().read();

  // Shared with the audio handler, which lives outside the widget tree.
  final database = AppDatabase.open();
  final artwork = ArtworkCache(channel, getApplicationCacheDirectory);
  // Header details and ReplayGain, for the player and the UI.
  final audioInfo = AudioInfoRepository(database.audioInfoDao);

  // Only effects the device has: just_audio creating a missing one would
  // break playback.
  final effectsInfo = await probeAudioEffects();
  final equalizer = effectsInfo.equalizer == null ? null : AndroidEqualizer();
  final loudness = effectsInfo.loudness ? AndroidLoudnessEnhancer() : null;
  final effects = JustAudioEffects(equalizer: equalizer, loudness: loudness);
  await applyEqualizerSettings(
    loadEqualizerSettings(preferences),
    effectsInfo,
    effects,
  );

  final handler = await AudioService.init(
    builder: () => HaraAudioHandler(
      // Unplayable queue entries are skipped by HaraAudioHandler itself.
      player: AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [?equalizer, ?loudness],
        ),
      ),
      recorder: PlayEventRecorder(database.playEventsDao),
      artwork: artwork,
      queueStore: database.queueStateDao,
      audioInfo: audioInfo,
      // Overridable for device checks:
      // --dart-define=HARAPLAY_PAUSED_TIMEOUT_S=30
      releaseForeground: () async {
        try {
          await const MethodChannel('haraplay/playback')
              .invokeMethod<bool>('releaseForeground');
        } on PlatformException {
          // Best effort: the notification then stays until the app closes.
        }
      },
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
      // stops the service after a while paused (pausedTimeout).
      androidStopForegroundOnPause: false,
    ),
  );
  await handler.configureSession();
  handler.setReplayGainMode(loadReplayGainMode(preferences));

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sdkIntProvider.overrideWithValue(sdkInt),
      initialMediaAccessProvider.overrideWithValue(access),
      mediaStoreChannelProvider.overrideWithValue(channel),
      appDatabaseProvider.overrideWithValue(database),
      artworkCacheProvider.overrideWithValue(artwork),
      playerProvider.overrideWithValue(handler),
      audioEffectsInfoProvider.overrideWithValue(effectsInfo),
      audioEffectsSinkProvider.overrideWithValue(effects),
      audioInfoSourceProvider.overrideWithValue(audioInfo),
      initialSystemTonesProvider.overrideWithValue(systemTones),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const HaraPlayApp()),
  );

  // Pick up files added or removed since the last launch. Onboarding runs
  // its own first sync; failures are kept in the controller's state.
  var started = false;
  void startLibrary() {
    if (started) return;
    started = true;
    // Last session's queue comes back paused, at the saved position.
    handler.restore().ignore();
    if (OnboardingRepository(preferences).readCompleted()) {
      container.read(librarySyncControllerProvider.notifier).sync().ignore();
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
}
