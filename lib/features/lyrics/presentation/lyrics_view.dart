import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/hara_icon_button.dart';
import '../../../core/widgets/hara_pressable.dart';
import '../../player/domain/queue_song.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/lyrics.dart';
import 'lyrics_providers.dart';

/// Lyrics in Now Playing, in place of the artwork: a bordered card with the
/// lyrics and a button to read them full screen.
class LyricsPanel extends StatelessWidget {
  const LyricsPanel({super.key, required this.song});

  final QueueSong song;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return HaraPressable(
      isButton: false,
      color: colors.surface,
      borderRadius: HaraRadius.lg,
      borderWidth: HaraBorder.regular,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                HaraRadius.lg - HaraBorder.regular,
              ),
              child: LyricsView(song: song),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: HaraIconButton(
              icon: HaraIcons.maximize2,
              tooltip: 'Full-screen lyrics',
              iconSize: HaraSizes.iconSmall,
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => LyricsScreen(song: song),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lyrics on their own page, in larger type.
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key, required this.song});

  final QueueSong song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Follow the player: the page shows whatever song is playing now.
    final current = ref.watch(playbackStatusProvider).value?.song ?? song;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current.title,
              style: textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              current.displayArtist,
              style: textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: LyricsView(song: current, large: true)),
    );
  }
}

/// A song's lyrics. Synced lyrics highlight the line being sung, scroll to
/// keep it in view (pausing while the user scrolls) and jump to a line when
/// it is tapped; plain lyrics are shown as text.
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key, required this.song, this.large = false});

  final QueueSong song;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return switch (ref.watch(lyricsProvider(lyricsKey(song)))) {
      AsyncData(value: final lyrics?) => _SyncedOrPlain(
        // A new song starts at the top with fresh scroll state.
        key: ValueKey(song.id),
        lyrics: lyrics,
        large: large,
      ),
      AsyncData() || AsyncError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(HaraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(HaraIcons.micVocal, color: colors.mutedForeground),
              const SizedBox(height: HaraSpacing.md),
              Text(
                'No lyrics for this song',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HaraSpacing.xs),
              Text(
                'Put a .lrc file with the same name next to the song, '
                'or add lyrics to its tags.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SyncedOrPlain extends ConsumerStatefulWidget {
  const _SyncedOrPlain({super.key, required this.lyrics, required this.large});

  final Lyrics lyrics;
  final bool large;

  @override
  ConsumerState<_SyncedOrPlain> createState() => _SyncedOrPlainState();
}

class _SyncedOrPlainState extends ConsumerState<_SyncedOrPlain> {
  /// After the user scrolls, auto-scroll waits this long before following
  /// the song again.
  static const _resumeAfter = Duration(seconds: 4);

  /// Lines turn current a little early, to cover the display delay.
  static const _lead = Duration(milliseconds: 150);

  late final List<GlobalKey> _keys = [
    for (var i = 0; i < widget.lyrics.lines.length; i++) GlobalKey(),
  ];
  int _active = -1;
  bool _userScrolling = false;
  Timer? _resume;

  @override
  void dispose() {
    _resume?.cancel();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.idle) {
      _resume?.cancel();
      _resume = Timer(_resumeAfter, () {
        _userScrolling = false;
        _scrollToActive();
      });
    } else {
      _resume?.cancel();
      _userScrolling = true;
    }
    return false;
  }

  void _scrollToActive() {
    if (_userScrolling || _active < 0 || !mounted) return;
    final target = _keys[_active].currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0.35,
        duration: HaraMotion.slow,
        curve: HaraMotion.emphasized,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    if (lyrics.synced) {
      final position =
          ref.watch(playbackPositionProvider).value ?? Duration.zero;
      final active = lyrics.activeIndex(position + _lead);
      if (active != _active) {
        _active = active;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
      }
    }
    final player = ref.read(playerProvider);
    final vertical = widget.large ? HaraSpacing.xxxl : HaraSpacing.xl;

    return NotificationListener<UserScrollNotification>(
      onNotification: _onScroll,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          HaraSpacing.lg,
          vertical,
          // Room for the full-screen button in the panel.
          widget.large ? HaraSpacing.lg : HaraSizes.minTouchTarget,
          vertical * 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lyrics.lines.length; i++)
              _Line(
                key: _keys[i],
                line: lyrics.lines[i],
                state: !lyrics.synced
                    ? _LineState.plain
                    : i == _active
                    ? _LineState.active
                    : i < _active
                    ? _LineState.past
                    : _LineState.upcoming,
                large: widget.large,
                onTap: lyrics.synced
                    ? () => player.seek(lyrics.lines[i].time!)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

enum _LineState { plain, past, active, upcoming }

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.line,
    required this.state,
    required this.large,
    this.onTap,
  });

  final LyricLine line;
  final _LineState state;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final base = large ? textTheme.headlineSmall! : textTheme.titleLarge!;
    final empty = line.text.trim().isEmpty;
    // A blank line is a verse break in plain lyrics, an instrumental
    // stretch in synced ones.
    if (empty && state == _LineState.plain) {
      return const SizedBox(height: HaraSpacing.md);
    }
    final text = empty ? '♪' : line.text;

    // The current line gets a marker-style brand fill behind its words.
    final style = switch (state) {
      _LineState.active => base.copyWith(
        color: colors.onPrimary,
        background: Paint()..color = colors.primary,
      ),
      _LineState.past => base.copyWith(color: colors.mutedForeground),
      _LineState.upcoming || _LineState.plain => base,
    };

    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: HaraSpacing.sm),
      child: Text(text, style: style),
    );
    if (onTap == null) {
      return Semantics(label: empty ? 'Instrumental' : null, child: body);
    }
    return Semantics(
      button: true,
      selected: state == _LineState.active,
      label: empty ? 'Instrumental' : line.text,
      hint: 'Play from this line',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HaraRadius.sm),
        child: SizedBox(width: double.infinity, child: body),
      ),
    );
  }
}
