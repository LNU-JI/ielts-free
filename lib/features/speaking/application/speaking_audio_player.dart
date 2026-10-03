/// Playback of a recorded speaking answer.
///
/// Replay plays back the **local** file the learner has just recorded in the
/// app's own documents directory, using `just_audio`. The audio never leaves
/// the device and no networking package is involved, which is what keeps this
/// compatible with the project's offline red line (see
/// docs/ARCHITECTURE-v0.1.md 8.1). The listening module keeps using the
/// on-device TTS engine for exactly the same reason.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:ielts_free/core/utils/logger.dart';

/// Plays a local recording.
abstract interface class SpeakingAudioPlayer {
  /// Plays the local file at [path] through the device's audio output.
  Future<void> play(String path);
}

/// [SpeakingAudioPlayer] backed by `just_audio`.
///
/// Works on Android, iOS, Windows, macOS and Linux alike — replay is available
/// on every platform the app targets, so there is no capability check to make.
class JustAudioSpeakingPlayer implements SpeakingAudioPlayer {
  JustAudioSpeakingPlayer();

  final AudioPlayer _player = AudioPlayer();
  bool _disposed = false;

  @override
  Future<void> play(String path) async {
    if (_disposed) {
      return;
    }
    try {
      // Stop whatever is still playing before starting the new answer.
      await _player.stop();
      await _player.setFilePath(path);
      await _player.play();
    } on Object catch (error, stackTrace) {
      appLogger.warning('Speaking replay failed.', error, stackTrace);
    }
  }

  /// Releases the native audio resources held by this player.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _player.dispose();
  }
}

/// The audio player used by the speaking session.
final Provider<SpeakingAudioPlayer> speakingAudioPlayerProvider =
    Provider<SpeakingAudioPlayer>((Ref ref) {
  final JustAudioSpeakingPlayer player = JustAudioSpeakingPlayer();
  ref.onDispose(player.dispose);
  return player;
});
