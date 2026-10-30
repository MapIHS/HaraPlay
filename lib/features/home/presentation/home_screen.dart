import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_icon_button.dart';

/// Home tab. Recently played, top songs and quick picks arrive in M10.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HaraPlay'),
        actions: [
          HaraIconButton(
            icon: HaraIcons.settings,
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(width: HaraSpacing.xs),
        ],
      ),
      body: const EmptyState(
        icon: HaraIcons.house,
        title: 'Welcome to HaraPlay',
        message: 'Your recently played songs and favourites will show up here.',
      ),
    );
  }
}
