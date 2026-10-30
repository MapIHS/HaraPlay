import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/licenses.dart';
import 'core/debug/frame_stats.dart';
import 'core/platform/media_store_channel.dart';
import 'core/storage/preferences.dart';
import 'features/library/presentation/library_providers.dart';
import 'features/onboarding/data/media_permission_service.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/presentation/onboarding_controllers.dart';

/// Initialises app-wide services before the first frame.
///
/// Later milestones add the audio service here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  if (FrameStats.enabled) FrameStats.start();
  final preferences = await createPreferences();
  final sdkInt = await MediaStoreChannel().sdkInt();
  // Checked before the first frame so the router starts on the right screen.
  final access = await MediaPermissionService(sdkInt: sdkInt).check();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sdkIntProvider.overrideWithValue(sdkInt),
      initialMediaAccessProvider.overrideWithValue(access),
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
