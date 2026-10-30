import 'package:flutter/material.dart';

import '../theme/hara_tokens.dart';

/// Shows a HaraPlay-styled modal bottom sheet (bordered top, drag handle).
///
/// [title] adds a header row; [builder] provides the body, which is wrapped
/// so it scrolls when taller than ~85% of the screen.
///
/// With [scrollable] false the sheet takes its full height and [builder]
/// gets a bounded box, for content with its own scroll view (e.g. a
/// reorderable list).
Future<T?> showHaraSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool scrollable = true,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
  return showModalBottomSheet<T>(
    context: context,
    // Above the tab shell, so the docked player and bottom navigation are
    // covered (and dimmed) instead of drawn over the sheet.
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (context) => scrollable
        ? _HaraSheetBody(title: title, builder: builder)
        : SizedBox(height: maxHeight, child: builder(context)),
  );
}

class _HaraSheetBody extends StatelessWidget {
  const _HaraSheetBody({required this.title, required this.builder});

  final String? title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: HaraSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HaraSpacing.gutter,
                0,
                HaraSpacing.gutter,
                HaraSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          builder(context),
        ],
      ),
    );
  }
}
