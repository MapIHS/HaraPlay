import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';

/// Plays [songs] from [index]; the list becomes the queue. The shuffle
/// setting is kept as it is.
Future<void> playSongs(
  WidgetRef ref,
  List<SongRow> songs, {
  int index = 0,
  required PlaySource source,
  String? label,
}) => ref
    .read(playerProvider)
    .playSongs(
      [for (final s in songs) QueueSong.fromRow(s)],
      startIndex: index,
      source: source,
      sourceLabel: label,
    );

/// Turns shuffle on and plays [songs] from a random song.
Future<void> shuffleSongs(
  WidgetRef ref,
  List<SongRow> songs, {
  required PlaySource source,
  String? label,
  Random? random,
}) => ref
    .read(playerProvider)
    .playSongs(
      [for (final s in songs) QueueSong.fromRow(s)],
      startIndex: (random ?? Random()).nextInt(songs.length),
      source: source,
      sourceLabel: label,
      shuffle: true,
    );
