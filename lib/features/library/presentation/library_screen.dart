import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/empty_state.dart';
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
          bottom: empty ? null : const _LibraryTabBar(),
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
class _LibraryTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _LibraryTabBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final label = Theme.of(context).textTheme.labelLarge!;
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.fromLTRB(
          HaraSpacing.gutter - HaraSpacing.xs,
          HaraSpacing.xs,
          HaraSpacing.gutter,
          HaraSpacing.md,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: HaraSpacing.xs),
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        indicator: const BoxDecoration(),
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.foreground,
        labelStyle: label,
        unselectedLabelStyle: label,
        tabs: [
          for (final (index, title) in LibraryScreen.tabs.indexed)
            _PillTab(index: index, title: title),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({required this.index, required this.title});

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.index == index;
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: HaraSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(HaraRadius.pill),
            border: Border.all(color: colors.border, width: HaraBorder.thin),
            boxShadow: [
              BoxShadow(
                color: selected ? colors.shadow : Colors.transparent,
                offset: const Offset(HaraShadow.small, HaraShadow.small),
              ),
            ],
          ),
          child: Text(title),
        );
      },
    );
  }
}
