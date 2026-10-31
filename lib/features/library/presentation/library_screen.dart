import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hara_pills.dart';
import 'library_providers.dart';
import 'library_tabs.dart';

/// Library tab: Songs, Albums, Artists, Folders and Genres.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  static const tabs = ['Songs', 'Albums', 'Artists', 'Folders', 'Genres'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(libraryCountsProvider);
    final empty = counts.value?.songs == 0;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: empty
              ? null
              : const HaraPillTabBar(titles: LibraryScreen.tabs),
        ),
        body: empty
            ? EmptyState(
                icon: HaraIcons.library,
                title: 'No music yet',
                message:
                    'Copy audio files to this phone, then scan again. Short '
                    'clips are hidden by the "Hide short audio" setting.',
                actionLabel: 'Scan again',
                onAction: () => rescanWithFeedback(context, ref),
              )
            : const TabBarView(
                children: [
                  SongsTab(),
                  AlbumsTab(),
                  ArtistsTab(),
                  FoldersTab(),
                  GenresTab(),
                ],
              ),
      ),
    );
  }
}

/// Scrollable pill tabs; the selected one is a brand pill with a hard shadow.
