/// Playback of a recorded speaking answer.
///
/// **No audio-playback package is bundled on purpose.** Pulling in `just_audio`
/// (or similar) would add a platform plugin to a project that must stay
/// dependency-light and fully offline — the same reasoning that keeps the
/// listening module on the platform TTS engine.
///
/// So replay delegates to the operating system's default media handler where
/// one exists (desktop) and reports [isSupported] = `false` elsewhere. On a
/// platform without a handler the UI simply disables the replay button; the
/// recording is still saved on device and can be opened from the file manager.
/// A real in-app player can be dropped in behind this interface later without
/// touching the session page.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/core/utils/logger.dart';

/// Plays a local recording.
abstract interface class SpeakingAudioPlayer {
  /// Whether replay is available on the current platform.
  bool get isSupported;

  /// Opens [path] with the platform's default media handler.
  Future<void> play(String path);
}

/// [SpeakingAudioPlayer] that hands the file to the OS default handler.
class SystemSpeakingAudioPlayer implements SpeakingAudioPlayer {
  const SystemSpeakingAudioPlayer();

  @override
  bool get isSupported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Future<void> play(String path) async {
    if (!isSupported) {
      return;
    }
    try {
      if (Platform.isWindows) {
        // `start` is a cmd builtin; the empty string is the window title.
        await Process.run('cmd', <String>['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', <String>[path]);
      } else {
        await Process.run('xdg-open', <String>[path]);
      }
    } on Object catch (error, stackTrace) {
      appLogger.warning('Speaking replay failed.', error, stackTrace);
    }
  }
}

/// The audio player used by the speaking session.
final Provider<SpeakingAudioPlayer> speakingAudioPlayerProvider =
    Provider<SpeakingAudioPlayer>(
  (Ref ref) => const SystemSpeakingAudioPlayer(),
);
