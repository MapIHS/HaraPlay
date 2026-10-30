import 'package:audio_service/audio_service.dart';
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
import 'features/library/presentation/library_providers.dart';
import 'features/onboarding/data/media_permission_service.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/presentation/onboarding_controllers.dart';
import 'features/player/data/hara_audio_handler.dart';
import 'features/player/data/play_event_recorder.dart';
import 'features/player/presentation/player_providers.dart';

/// Initialises app-wide services before the first frame: preferences, the
/// database, and the audio service that owns playback.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  if (FrameStats.enabled) FrameStats.start();
  final preferences = await createPreferences();
  final channel = MediaStoreChannel();
  final sdkInt = await channel.sdkInt();
  // Checked before the first frame so the router starts on the right screen.
  final access = await MediaPermissionService(sdkInt: sdkInt).check();

  // Shared with the audio handler, which lives outside the widget tree.
  final database = AppDatabase.open();
  final artwork = ArtworkCache(channel, getApplicationCacheDirectory);
  final handler = await AudioService.init(
    builder: () => HaraAudioHandler(
      player: AudioPlayer(),
      recorder: PlayEventRecorder(database.playEventsDao),
      artwork: artwork,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mmi.haraplay.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'Shows what is playing.',
      androidNotificationIcon: 'drawable/ic_stat_haraplay',
      androidStopForegroundOnPause: true,
    ),
  );
  await handler.configureSession();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sdkIntProvider.overrideWithValue(sdkInt),
      initialMediaAccessProvider.overrideWithValue(access),
      mediaStoreChannelProvider.overrideWithValue(channel),
      appDatabaseProvider.overrideWithValue(database),
      artworkCacheProvider.overrideWithValue(artwork),
      playerProvider.overrideWithValue(handler),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const HaraPlayApp()),
  );

  // Pick up files added or removed since the last launch. Onboarding runs
  // its own first sync; failures are kept in the controller's state.
  final onboarded = OnboardingRepository(preferences).readCompleted();
  if (access == MediaAccess.granted && onboarded) {
    container.read(librarySyncControllerProvider.notifier).sync().ignore();
  }
}
