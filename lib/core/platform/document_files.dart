import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the user picked to open.
typedef OpenedFile = ({String? name, String? path, Uint8List bytes});

/// Saving and opening single files through Android's document picker
/// (see `DocumentFilesPlugin.kt`). No storage permission is needed.
class DocumentFiles {
  const DocumentFiles({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('haraplay/documents');

  final MethodChannel _channel;

  /// Lets the user choose where to save [bytes] as [fileName]. Returns the
  /// saved file's name (the user may change it), or null if cancelled.
  Future<String?> save({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final reply = await _channel.invokeMethod<Object>('saveFile', {
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
    });
    return switch (reply) {
      final String name => name,
      true => fileName,
      _ => null,
    };
  }

  /// Lets the user pick a file of one of [mimeTypes]; null if cancelled.
  Future<OpenedFile?> open({required List<String> mimeTypes}) async {
    final reply = await _channel.invokeMapMethod<String, Object?>('openFile', {
      'mimeTypes': mimeTypes,
    });
    if (reply == null) return null;
    return (
      name: reply['name'] as String?,
      path: reply['path'] as String?,
      bytes: reply['bytes']! as Uint8List,
    );
  }
}

final documentFilesProvider = Provider<DocumentFiles>(
  (ref) => const DocumentFiles(),
);
