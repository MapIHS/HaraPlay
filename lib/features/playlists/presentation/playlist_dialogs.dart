import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/hara_dialog_actions.dart';
import '../domain/playlist_models.dart';

/// Asks for a playlist name; returns the cleaned name, or null if
/// cancelled.
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) => showDialog<String>(
  context: context,
  useRootNavigator: true,
  builder: (_) =>
      _NameDialog(title: title, confirmLabel: confirmLabel, initial: initial),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _name => cleanPlaylistName(_controller.text);

  void _submit() {
    final name = _name;
    if (name != null) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxPlaylistNameLength),
        ],
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actionsPadding: HaraDialogActions.padding,
      actions: [
        HaraDialogActions(
          confirmLabel: widget.confirmLabel,
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _name == null ? null : _submit,
        ),
      ],
    );
  }
}

/// Confirms deleting the playlist [name]; true if confirmed.
Future<bool> confirmDeletePlaylist(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text('"$name" will be deleted. The songs stay on your phone.'),
        actionsPadding: HaraDialogActions.padding,
        actions: [
          HaraDialogActions(
            confirmLabel: 'Delete',
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ??
    false;
