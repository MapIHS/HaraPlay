import 'package:flutter/material.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/widgets/empty_state.dart';

/// Liked songs. Placeholder until M9.
class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liked songs')),
      body: const EmptyState(
        icon: HaraIcons.heart,
        title: 'No liked songs yet',
        message: 'Tap the heart on any song to keep it here.',
      ),
    );
  }
}
