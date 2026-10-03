/// Microphone capture for the speaking module.
///
/// Wraps `package:record` behind a tiny interface so the session controller can
/// be exercised with a fake recorder and so the UI degrades cleanly when the
/// microphone permission is refused (PRD §4.6 / BRIEF §20).
///
/// **Privacy:** recordings are written to a private sub-directory of the app's
/// own documents directory and are never uploaded — the app declares no
/// `INTERNET` permission in its release manifest.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records one answer to a local file.
abstract interface class SpeakingRecorder {
  /// Whether microphone permission is currently granted.
  ///
  /// Asking also triggers the OS permission prompt on the first call.
  Future<bool> hasPermission();

  /// Starts a new recording, writing to [path].
  Future<void> start(String path);

  /// Stops the current recording and returns the written path, or `null`.
  Future<String?> stop();

  /// Releases the underlying recorder.
  Future<void> dispose();
}

/// `package:record`-backed [SpeakingRecorder].
class DeviceSpeakingRecorder implements SpeakingRecorder {
  DeviceSpeakingRecorder([AudioRecorder? recorder])
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Sub-directory of the app documents directory that holds speaking recordings.
const String kSpeakingAudioDirName = 'speaking';

/// Builds the on-device path for one answer's recording.
///
/// Kept out of the recorder so it stays trivially testable and so the controller
/// owns the naming scheme (`speak_<topic>_<question>_<timestamp>.m4a`).
Future<String> speakingRecordingPath({
  required int topicId,
  required int questionId,
  required DateTime now,
}) async {
  final Directory documents = await getApplicationDocumentsDirectory();
  final Directory dir = Directory(p.join(documents.path, kSpeakingAudioDirName));
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  final String name =
      'speak_${topicId}_${questionId}_${now.millisecondsSinceEpoch}.m4a';
  return p.join(dir.path, name);
}

/// Factory for a fresh [SpeakingRecorder].
///
/// A **factory** (not a single shared instance) because one recorder belongs to
/// one session and is disposed with it; injecting the factory keeps the
/// controller testable with a fake.
final Provider<SpeakingRecorder Function()> speakingRecorderFactoryProvider =
    Provider<SpeakingRecorder Function()>(
  (Ref ref) => () => DeviceSpeakingRecorder(),
);
