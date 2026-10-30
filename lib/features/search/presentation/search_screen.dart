import 'package:flutter/material.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/widgets/empty_state.dart';

/// Search tab. Placeholder until M10.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const EmptyState(
        icon: HaraIcons.search,
        title: 'Search your music',
        message: 'Find songs, albums and artists on this device.',
      ),
    );
  }
}
