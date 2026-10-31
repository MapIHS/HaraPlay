import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player.dart';
import '../domain/queue_song.dart';
import '../domain/sleep_timer_state.dart';

/// The app's [Player], created with audio_service in `bootstrap.dart`.
final playerProvider = Provider<Player>(
  (ref) => throw UnimplementedError('playerProvider must be overridden'),
);

final playbackStatusProvider = StreamProvider<PlaybackStatus>(
  (ref) => ref.watch(playerProvider).status,
);

/// Updates several times a second; watch it only in small widgets.
final playbackPositionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(playerProvider).position,
);

/// The ID of the song that is loaded in the player, if any.
final currentSongIdProvider = Provider<int?>(
  (ref) => ref.watch(playbackStatusProvider).value?.song?.id,
);

/// The sleep timer's state.
final sleepTimerProvider = StreamProvider<SleepTimerState>(
  (ref) => ref.watch(playerProvider).sleepTimer,
);
