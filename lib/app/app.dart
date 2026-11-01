import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/hara_theme.dart';
import '../core/theme/palettes.dart';
import '../features/settings/presentation/color_choice_controller.dart';
import '../features/settings/presentation/theme_mode_controller.dart';
import 'router.dart';

/// Root widget: themes plus the go_router configuration.
class HaraPlayApp extends ConsumerStatefulWidget {
  const HaraPlayApp({super.key});

  @override
  ConsumerState<HaraPlayApp> createState() => _HaraPlayAppState();
}

class _HaraPlayAppState extends ConsumerState<HaraPlayApp> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    // A new wallpaper changes the system colours while the app is away.
    onResume: () => ref.read(systemTonesProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // Starts listening.
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (light, dark) = HaraPalettes.of(
      ref.watch(colorChoiceProvider),
      ref.watch(systemTonesProvider),
    );
    return MaterialApp.router(
      // The recents-screen label; debug builds are "HaraPlay Dev".
      title: kDebugMode ? 'HaraPlay Dev' : 'HaraPlay',
      debugShowCheckedModeBanner: false,
      theme: HaraTheme.build(light),
      darkTheme: HaraTheme.build(dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
