import 'package:flutter/widgets.dart';

import 'app/app.dart';

/// Initialises app-wide services before the first frame.
///
/// Later milestones add the database, audio service and Riverpod scope here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HaraPlayApp());
}
