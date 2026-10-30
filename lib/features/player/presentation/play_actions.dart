import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';

/// Plays [songs] from [index]; the list becomes the queue.
Future<void> playSongs(
  WidgetRef ref,
  List<SongRow> songs, {
  int index = 0,
  required PlaySource source,
}) => ref
    .read(playerProvider)
    .playSongs(
      [for (final s in songs) QueueSong.fromRow(s)],
      startIndex: index,
      source: source,
    );

/// Plays [songs] in a random order. (The shuffle *mode*, which can be
/// turned off again, arrives with Now Playing in M7.)
Future<void> shuffleSongs(
  WidgetRef ref,
  List<SongRow> songs, {
  required PlaySource source,
  Random? random,
}) => playSongs(ref, [...songs]..shuffle(random), source: source);
