import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/widgets/empty_state.dart';

/// Playlists tab. Liked songs and user playlists arrive in M9.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: EmptyState(
        icon: HaraIcons.listMusic,
        title: 'Your playlists',
        message: 'Liked songs and the playlists you create will live here.',
        actionLabel: 'Open Liked songs',
        onAction: () => context.push(AppRoutes.likedSongs),
      ),
    );
  }
}
