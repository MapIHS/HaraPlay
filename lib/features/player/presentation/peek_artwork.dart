import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/artwork/song_artwork.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';
import 'seek_bar.dart';

/// Now Playing's large artwork.
///
/// - Drag sideways: the neighbouring song's artwork follows the finger in
///   from the side. Letting go past [commitFraction] of the width (or with
///   a fling) moves to that song; otherwise it springs back. At either end
///   of the queue the artwork only stretches a little.
/// - Double-tap the left or right half to seek back or forward 10 s;
///   quick repeated double-taps add up ("+30 s").
class PeekArtwork extends ConsumerStatefulWidget {
  const PeekArtwork({super.key, required this.status});

  /// How far (of the artwork's width) a drag must go to change song.
  static const double commitFraction = 0.35;

  /// A fling at least this fast (logical px/s) changes song regardless.
  static const double flingVelocity = 800;

  final PlaybackStatus status;

  @override
  ConsumerState<PeekArtwork> createState() => _PeekArtworkState();
}

class _PeekArtworkState extends ConsumerState<PeekArtwork>
    with SingleTickerProviderStateMixin {
  /// The artwork's sideways offset in logical pixels.
  late final AnimationController _dx = AnimationController.unbounded(
    vsync: this,
  );

  /// The finger's travel; differs from [_dx] where there's no neighbour.
  double _drag = 0;

  /// Set after a committed swipe until the player reports the new song;
  /// meanwhile the neighbour stays in the centre.
  int? _landingOn;
  Timer? _landingTimeout;

  // The ±10 s double-tap.
  double _tapX = 0;
  int _flashSeconds = 0;
  bool _flashForward = true;
  bool _flashVisible = false;
  Timer? _flashTimer;

  /// The last double-tap's target, kept for a second (see [_onDoubleTap]).
  Duration? _seekTarget;
  Timer? _seekTargetTimer;

  static const _gap = HaraSpacing.xl;

  @override
  void didUpdateWidget(PeekArtwork old) {
    super.didUpdateWidget(old);
    final landing = _landingOn;
    if (landing != null && widget.status.song?.id == landing) _land();
    if (widget.status.song?.id != old.status.song?.id) _seekTarget = null;
  }

  void _land() {
    _landingTimeout?.cancel();
    _landingOn = null;
    _dx.value = 0;
  }

  @override
  void dispose() {
    _dx.dispose();
    _landingTimeout?.cancel();
    _flashTimer?.cancel();
    _seekTargetTimer?.cancel();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// The queue index in the drag's direction: left (negative) is next.
  int? _target(double direction) {
    final status = widget.status;
    final index = status.neighbour(direction < 0 ? 1 : -1);
    return index == status.queueIndex ? null : index;
  }

  QueueSong? _songAt(int? index) =>
      index == null ? null : widget.status.queue[index];

  void _onDragStart(DragStartDetails _) {
    if (_landingOn != null) return;
    _dx.stop();
    _drag = _dx.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_landingOn != null) return;
    _drag += details.primaryDelta ?? 0;
    // Rubber band where there is nothing to move to.
    _dx.value = _target(_drag) == null ? _drag * 0.2 : _drag;
  }

  void _onDragEnd(DragEndDetails details, double size) {
    if (_landingOn != null) return;
    final velocity = details.primaryVelocity ?? 0;
    final dx = _dx.value;
    final travel = size + _gap;
    final flungLeft = velocity <= -PeekArtwork.flingVelocity;
    final flungRight = velocity >= PeekArtwork.flingVelocity;
    final goLeft =
        (dx < -size * PeekArtwork.commitFraction && !flungRight) || flungLeft;
    final goRight =
        (dx > size * PeekArtwork.commitFraction && !flungLeft) || flungRight;
    final direction = goLeft ? -1.0 : (goRight ? 1.0 : 0.0);
    final index = direction == 0 ? null : _target(direction);
    if (index == null) {
      _springTo(0, velocity);
      return;
    }
    final song = widget.status.queue[index];
    _landingOn = song.id;
    _landingTimeout = Timer(const Duration(seconds: 1), () {
      if (mounted && _landingOn != null) _land();
    });
    unawaited(_commit(direction * travel, velocity, index));
  }

  Future<void> _commit(double end, double velocity, int index) async {
    if (!_reduceMotion) {
      final remaining = (end - _dx.value).abs() / end.abs();
      await _dx.animateTo(
        end,
        duration: HaraMotion.medium * remaining.clamp(0.3, 1.0),
        curve: HaraMotion.decelerate,
      );
    } else {
      _dx.value = end;
    }
    if (!mounted) return;
    await ref.read(playerProvider).skipTo(index);
  }

  void _springTo(double target, double velocity) {
    if (_reduceMotion) {
      _dx.value = target;
      return;
    }
    _dx.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 500, damping: 32),
        _dx.value,
        target,
        velocity,
      ),
    );
  }

  void _onDoubleTap(double width) {
    final forward = _tapX >= width / 2;
    final duration = widget.status.duration;
    if (duration <= Duration.zero) return;
    // Rapid double-taps build on the last target: the position stream may
    // not have caught up with the previous seek yet.
    final from =
        _seekTarget ??
        ref.read(playbackPositionProvider).value ??
        Duration.zero;
    var target = from + (forward ? seekStep : -seekStep);
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    _seekTarget = target;
    _seekTargetTimer?.cancel();
    _seekTargetTimer = Timer(
      const Duration(seconds: 1),
      () => _seekTarget = null,
    );
    unawaited(ref.read(playerProvider).seek(target));

    _flashTimer?.cancel();
    setState(() {
      final sameWay = _flashVisible && _flashForward == forward;
      _flashSeconds = (sameWay ? _flashSeconds : 0) + seekStep.inSeconds;
      _flashForward = forward;
      _flashVisible = true;
    });
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flashVisible = false);
    });
  }

  Widget _art(QueueSong song, double size) => SongArtwork(
    key: ValueKey(song.id),
    songId: song.id,
    albumId: song.albumId,
    version: song.version,
    size: size - HaraShadow.offset,
    shadow: true,
    borderRadius: HaraRadius.xl,
    borderWidth: HaraBorder.regular,
  );

  @override
  Widget build(BuildContext context) {
    final song = widget.status.song!;
    final player = ref.read(playerProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final next = _songAt(_target(-1));
        final previous = _songAt(_target(1));
        return Semantics(
          image: true,
          label: 'Artwork',
          hint:
              'Swipe for the next or previous song; double-tap a side to '
              'skip 10 seconds',
          customSemanticsActions: {
            const CustomSemanticsAction(label: 'Next song'): player.next,
            const CustomSemanticsAction(label: 'Previous song'):
                player.previous,
            const CustomSemanticsAction(label: 'Forward 10 seconds'): () {
              _tapX = size;
              _onDoubleTap(size);
            },
            const CustomSemanticsAction(label: 'Back 10 seconds'): () {
              _tapX = 0;
              _onDoubleTap(size);
            },
          },
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: (d) => _onDragEnd(d, size),
            onDoubleTapDown: (d) => _tapX = d.localPosition.dx,
            onDoubleTap: () => _onDoubleTap(size),
            child: SizedBox.square(
              dimension: size,
              child: AnimatedBuilder(
                animation: _dx,
                builder: (context, _) {
                  final dx = _dx.value;
                  final travel = size + _gap;
                  final t = (dx.abs() / travel).clamp(0.0, 1.0);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Both neighbours stay built (so their artwork is
                      // loaded before the finger brings them in), but only
                      // the one being revealed is painted.
                      for (final (neighbour, side) in [
                        (next, 1.0),
                        (previous, -1.0),
                      ])
                        if (neighbour != null)
                          Visibility(
                            visible: dx * side < 0,
                            maintainState: true,
                            maintainAnimation: true,
                            maintainSize: true,
                            child: Transform.translate(
                              offset: Offset(side * travel + dx, 0),
                              child: Transform.scale(
                                scale: 0.92 + 0.08 * t,
                                child: _art(neighbour, size),
                              ),
                            ),
                          ),
                      Transform.translate(
                        offset: Offset(dx, 0),
                        child: Transform.scale(
                          scale: 1 - 0.08 * t,
                          child: _art(song, size),
                        ),
                      ),
                      _SeekFlash(
                        visible: _flashVisible,
                        forward: _flashForward,
                        seconds: _flashSeconds,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The "+10 s" / "−10 s" chip on the side that was double-tapped.
class _SeekFlash extends StatelessWidget {
  const _SeekFlash({
    required this.visible,
    required this.forward,
    required this.seconds,
  });

  final bool visible;
  final bool forward;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final style = HaraTextStyles.of(context).monoStrong
        .copyWith(color: colors.foreground);
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: forward
              ? const Alignment(0.7, 0)
              : const Alignment(-0.7, 0),
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: HaraMotion.fast,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HaraSpacing.md,
                  vertical: HaraSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(HaraRadius.pill),
                  border: Border.all(
                    color: colors.border,
                    width: HaraBorder.regular,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      offset: const Offset(HaraShadow.small, HaraShadow.small),
                    ),
                  ],
                ),
                child: Text(
                  forward ? '+$seconds s' : '−$seconds s',
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
