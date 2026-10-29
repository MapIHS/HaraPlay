import 'package:flutter/material.dart';

import '../theme/hara_tokens.dart';

/// Shows a HaraPlay-styled modal bottom sheet (bordered top, drag handle).
///
/// [title] adds a header row; [builder] provides the body, which is wrapped
/// so it scrolls when taller than ~85% of the screen.
Future<T?> showHaraSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (context) => _HaraSheetBody(title: title, builder: builder),
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
