import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/widgets/empty_state.dart';

/// Library tab. Songs, albums, artists, folders and genres arrive in M5.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: EmptyState(
        icon: HaraIcons.library,
        title: 'Your library',
        message: 'Songs, albums, artists, folders and genres will live here.',
        actionLabel: 'Open sample album',
        onAction: () => context.push(AppRoutes.album(1)),
      ),
    );
  }
}
