import 'package:just_audio/just_audio.dart';

import 'crossfade.dart';

/// The crossfade's second player on just_audio. It never takes audio
/// focus or reacts to interruptions itself: the main player owns the
/// session, and the handler pauses this one with it.
class JustAudioTailPlayer implements TailPlayer {
  JustAudioTailPlayer({List<AndroidAudioEffect> effects = const []})
    : _player = AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
        audioPipeline: AudioPipeline(androidAudioEffects: effects),
      );

  final AudioPlayer _player;

  @override
  Future<void> load(Uri uri, Duration position) async {
    await _player.setAudioSource(
      AudioSource.uri(uri),
      initialPosition: position,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Duration get position => _player.position;

  @override
  bool get playing => _player.playing;

  @override
  bool get started =>
      _player.playing && _player.processingState == ProcessingState.ready;

  @override
  Future<void> dispose() => _player.dispose();
}
