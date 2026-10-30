import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/hara_theme.dart';
import '../features/settings/presentation/theme_mode_controller.dart';
import 'router.dart';

/// Root widget: themes plus the go_router configuration.
class HaraPlayApp extends ConsumerWidget {
  const HaraPlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'HaraPlay',
      debugShowCheckedModeBanner: false,
      theme: HaraTheme.light,
      darkTheme: HaraTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
