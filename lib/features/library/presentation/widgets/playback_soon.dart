import 'package:flutter/material.dart';

/// Play and Shuffle are visible from M5, playback arrives in M6.
void showPlaybackComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Playback arrives in the next update.')),
    );
}
