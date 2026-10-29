import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/hara_theme.dart';
import '../features/design_gallery/presentation/design_gallery_screen.dart';
import '../features/settings/presentation/theme_mode_controller.dart';

/// Root widget. The router replaces the design gallery as home in M2.
class HaraPlayApp extends ConsumerWidget {
  const HaraPlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'HaraPlay',
      debugShowCheckedModeBanner: false,
      theme: HaraTheme.light,
      darkTheme: HaraTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const DesignGalleryScreen(),
    );
  }
}
