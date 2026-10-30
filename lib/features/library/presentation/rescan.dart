import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/library_dao.dart';
import 'library_providers.dart';

/// Syncs the library and reports the outcome in a snackbar.
Future<void> rescanWithFeedback(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  String message;
  try {
    final result = await ref
        .read(librarySyncControllerProvider.notifier)
        .sync();
    message = describeSync(result);
  } on Object {
    message = "Couldn't scan your music. Please try again.";
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A short, human summary of a sync for a snackbar.
String describeSync(SyncResult result) {
  final parts = [
    if (result.added > 0) '${result.added} added',
    if (result.updated > 0) '${result.updated} updated',
    if (result.removed > 0) '${result.removed} removed',
  ];
  // A pure re-key changes nothing the user can see.
  if (parts.isEmpty) return 'Library is up to date: ${_songs(result.total)}.';
  return '${parts.join(', ')}. ${_songs(result.total)} in total.';
}

String _songs(int count) => count == 1 ? '1 song' : '$count songs';
