import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/preferences.dart';

/// Initialises app-wide services before the first frame.
///
/// Later milestones add the database and audio service here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await createPreferences();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const HaraPlayApp(),
    ),
  );
}
