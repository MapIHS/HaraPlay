import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/play_events_dao.dart';
import '../domain/queue_song.dart';

/// Records listening history (docs/PLAN.md §3, "Play events").
///
/// Counts time actually spent playing, measured on a monotonic clock, so
/// seeking never adds or removes listened time. A row is inserted once a
/// listen passes [minListen], then updated every [saveEvery], on pause and
/// when the track changes, so a killed app loses at most [saveEvery].
/// Whether a listen "counts as a play" is decided later, at query time.
class PlayEventRecorder {
  PlayEventRecorder(
    this._dao, {
    Duration Function()? monotonic,
    this._wallClock = DateTime.now,
    this.minListen = const Duration(seconds: 1),
    this.saveEvery = const Duration(seconds: 10),
  }) : _monotonic = monotonic ?? _stopwatchClock();

  final PlayEventsDao _dao;
  final Duration Function() _monotonic;
  final DateTime Function() _wallClock;
  final Duration minListen;
  final Duration saveEvery;

  /// Within this distance of the end, leaving a track counts as finishing it.
  static const completionMargin = Duration(seconds: 2);

  QueueSong? _track;
  PlaySource _source = PlaySource.songs;
  DateTime? _startedAt;
  Duration _listened = Duration.zero;
  Duration? _activeSince;
  Duration _lastPosition = Duration.zero;
  Duration _lastSaved = Duration.zero;
  bool _ended = false;
  Future<int?>? _eventId;

  /// Serialises database writes in call order.
  Future<void> _writes = Future.value();

  static Duration Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  Duration get _listenedNow {
    final since = _activeSince;
    return since == null ? _listened : _listened + (_monotonic() - since);
  }

  /// The current track changed (or playback stopped, with null). Finishes
  /// the previous listen.
  void trackChanged(QueueSong? track, {required PlaySource source}) {
    if (track == _track && source == _source) return;
    _startListen(track, source);
  }

  /// The current track starts again from the beginning ("previous" while
  /// past the first seconds, or repeat-one): that is a new listen.
  void trackRestarted() => _startListen(_track, _source);

  void _startListen(QueueSong? track, PlaySource source) {
    final wasActive = _activeSince != null;
    _finish();
    _track = track;
    _source = source;
    _listened = Duration.zero;
    _lastPosition = Duration.zero;
    _lastSaved = Duration.zero;
    _startedAt = null;
    _ended = false;
    _eventId = null;
    _activeSince = null;
    if (wasActive && track != null) _activate();
  }

  /// Playback is audibly running ([active] = playing and not buffering).
  void activeChanged(bool active) {
    if (active == (_activeSince != null)) return;
    if (active) {
      _activate();
    } else {
      _listened = _listenedNow;
      _activeSince = null;
      _save();
    }
  }

  void _activate() {
    if (_track == null) return;
    _startedAt ??= _wallClock();
    _activeSince = _monotonic();
  }

  void positionChanged(Duration position) {
    _lastPosition = position;
    if (_listenedNow - _lastSaved >= saveEvery) _save();
  }

  /// The track played to its end (e.g. the queue finished).
  void trackEnded() {
    _ended = true;
    activeChanged(false);
  }

  /// Writes everything still pending (on stop and dispose).
  Future<void> flush() {
    _finish();
    _track = null;
    return _writes;
  }

  bool get _completed {
    final track = _track;
    if (track == null) return false;
    if (_ended) return true;
    final duration = track.duration;
    return duration > Duration.zero &&
        _lastPosition >= duration - completionMargin;
  }

  void _finish() {
    if (_track == null) return;
    _listened = _listenedNow;
    _activeSince = null;
    _save();
  }

  void _save() {
    final track = _track;
    final startedAt = _startedAt;
    if (track == null || startedAt == null) return;
    final listened = _listenedNow;
    if (listened < minListen) return;
    _lastSaved = listened;
    final completed = _completed;

    final existing = _eventId;
    if (existing == null) {
      final source = _source;
      _eventId = _enqueue(
        () => _dao.insertEvent(
          PlayEventsCompanion.insert(
            songId: Value(track.id),
            songPath: track.path,
            title: track.title,
            artist: Value(track.artist),
            album: Value(track.album),
            startedAt: startedAt.millisecondsSinceEpoch,
            listenedMs: listened.inMilliseconds,
            durationMs: track.duration.inMilliseconds,
            completed: completed,
            source: source,
          ),
        ),
      );
    } else {
      _enqueue(() async {
        final id = await existing;
        if (id != null) {
          await _dao.updateProgress(
            id,
            listenedMs: listened.inMilliseconds,
            completed: completed,
          );
        }
        return id;
      });
    }
  }

  Future<int?> _enqueue(Future<int?> Function() write) {
    final result = _writes.then((_) => write()).catchError((Object error) {
      // History must never break playback (e.g. the song row was deleted
      // in a rescan and the foreign key rejects the insert).
      debugPrint('PlayEventRecorder: write failed: $error');
      return null;
    });
    _writes = result;
    return result;
  }
}
