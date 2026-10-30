import 'package:flutter/material.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/widgets/empty_state.dart';

/// Album detail. Placeholder until M5.
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key, required this.albumId});

  final int albumId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: EmptyState(
        icon: HaraIcons.disc3,
        title: 'Album #$albumId',
        message: 'Album artwork and tracks will appear here.',
      ),
    );
  }
}
