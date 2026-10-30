import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/licenses.dart';
import 'core/platform/media_store_channel.dart';
import 'core/storage/preferences.dart';
import 'features/onboarding/data/media_permission_service.dart';
import 'features/onboarding/presentation/onboarding_controllers.dart';

/// Initialises app-wide services before the first frame.
///
/// Later milestones add the database and audio service here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  final preferences = await createPreferences();
  final sdkInt = await MediaStoreChannel().sdkInt();
  // Checked before the first frame so the router starts on the right screen.
  final access = await MediaPermissionService(sdkInt: sdkInt).check();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sdkIntProvider.overrideWithValue(sdkInt),
        initialMediaAccessProvider.overrideWithValue(access),
      ],
      child: const HaraPlayApp(),
    ),
  );
}
