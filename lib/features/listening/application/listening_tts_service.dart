/// On-device text-to-speech for the listening module.
///
/// The content pack ships **no audio**: every [ListeningCue] is synthesised by
/// the platform TTS engine, one sentence at a time, so the learner can replay /
/// slow down / shadow a single line. This keeps the app fully offline.
///
/// The service never throws into the UI: when the platform has no usable voice
/// it flips [isAvailable] to `false` and the page shows the "TTS unavailable"
/// notice while every other feature keeps working.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:ielts_free/core/models/listening_cue.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Wraps [FlutterTts] with the listening module's speaking rules.
class ListeningTtsService {
  /// Creates a service over a fresh [FlutterTts] instance.
  ListeningTtsService({FlutterTts? engine}) : _tts = engine ?? FlutterTts();

  final FlutterTts _tts;

  /// Normal speaking rate (0.0–1.0).
  static const double normalRate = 0.5;

  /// Slowed-down rate used by the "慢速" control.
  static const double slowRate = 0.32;

  bool _available = false;
  bool _speaking = false;

  /// Monotonic token used to cancel an in-flight sequential playback.
  int _generation = 0;

  /// Available voices (empty when the platform exposes none).
  List<Map<String, String>> _voices = const <Map<String, String>>[];

  /// Speaker label → stable index, assigned in order of first appearance so
  /// two speakers always get two different pitches / voices.
  final Map<String, int> _speakerOrder = <String, int>{};

  /// Called whenever the "speaking" flag changes (used to swap the play / stop
  /// button). Cleared by the page on dispose.
  ValueChanged<bool>? onSpeakingChanged;

  /// Whether a usable TTS voice was found.
  bool get isAvailable => _available;

  /// Whether the engine is currently reading.
  bool get isSpeaking => _speaking;

  /// Prepares the engine. Returns whether TTS is usable.
  ///
  /// [accent] is the section's target accent wire value (`british` / `american`
  /// / …); it is mapped to a BCP-47 locale, falling back to `en-US`.
  Future<bool> init({String? accent}) async {
    final String locale = _localeForAccent(accent);
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(normalRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      final Object? available = await _tts.isLanguageAvailable(locale);
      _available = available == true;
      if (_available) {
        await _loadVoices();
      }
    } on Object catch (error, stackTrace) {
      appLogger.warning('TTS init failed.', error, stackTrace);
      _available = false;
    }
    return _available;
  }

  /// Clears the speaker→voice mapping (call when a new section opens).
  void beginSection() {
    _speakerOrder.clear();
  }

  /// Reads one cue, stopping anything already playing.
  Future<void> speakCue(ListeningCue cue, {bool slow = false}) async {
    if (!_available) {
      return;
    }
    await stop();
    final int generation = ++_generation;
    _setSpeaking(true);
    try {
      await _prepareSpeaker(cue.speaker);
      await _tts.setSpeechRate(slow ? slowRate : normalRate);
      await _tts.speak(cue.text);
    } on Object catch (error, stackTrace) {
      appLogger.warning('TTS speak failed.', error, stackTrace);
    } finally {
      if (generation == _generation) {
        _setSpeaking(false);
      }
    }
  }

  /// Reads every cue in order, switching voice / pitch between speakers.
  Future<void> speakAll(List<ListeningCue> cues, {bool slow = false}) async {
    if (!_available || cues.isEmpty) {
      return;
    }
    await stop();
    final int generation = ++_generation;
    _setSpeaking(true);
    try {
      for (final ListeningCue cue in cues) {
        if (generation != _generation) {
          return;
        }
        await _prepareSpeaker(cue.speaker);
        await _tts.setSpeechRate(slow ? slowRate : normalRate);
        await _tts.speak(cue.text);
      }
    } on Object catch (error, stackTrace) {
      appLogger.warning('TTS sequential speak failed.', error, stackTrace);
    } finally {
      if (generation == _generation) {
        _setSpeaking(false);
      }
    }
  }

  /// Stops playback and cancels any sequential run.
  Future<void> stop() async {
    _generation++;
    _setSpeaking(false);
    try {
      await _tts.stop();
    } on Object catch (error, stackTrace) {
      appLogger.warning('TTS stop failed.', error, stackTrace);
    }
  }

  /// Releases the engine. Called from the provider's `onDispose`.
  Future<void> dispose() async {
    onSpeakingChanged = null;
    await stop();
  }

  // --- internals ----------------------------------------------------------

  void _setSpeaking(bool value) {
    if (_speaking == value) {
      return;
    }
    _speaking = value;
    onSpeakingChanged?.call(value);
  }

  /// Applies a distinct voice + pitch for [speaker].
  Future<void> _prepareSpeaker(String? speaker) async {
    final int index = _indexForSpeaker(speaker);
    // Pitch always differs, so speakers stay distinguishable even on platforms
    // that expose a single voice.
    final double pitch = (1.0 + (index - 1) * 0.09).clamp(0.6, 1.8).toDouble();
    try {
      await _tts.setPitch(pitch);
    } on Object catch (error, stackTrace) {
      appLogger.warning('TTS setPitch failed.', error, stackTrace);
    }

    final Map<String, String>? voice = _voiceForIndex(index);
    try {
      if (voice == null) {
        await _tts.clearVoice();
      } else {
        await _tts.setVoice(voice);
      }
    } on Object catch (error, stackTrace) {
      appLogger.warning('TTS setVoice failed.', error, stackTrace);
    }
  }

  int _indexForSpeaker(String? speaker) {
    final String key = (speaker ?? '').trim().toUpperCase();
    if (key.isEmpty) {
      return 1;
    }
    final int? existing = _speakerOrder[key];
    if (existing != null) {
      return existing;
    }
    final int assigned = _speakerOrder.length + 1;
    _speakerOrder[key] = assigned;
    return assigned;
  }

  Map<String, String>? _voiceForIndex(int index) {
    final List<Map<String, String>> english = _voices
        .where((Map<String, String> v) => _isEnglishVoice(v))
        .toList(growable: false);
    if (english.isEmpty) {
      return null;
    }
    // Only cycle when the platform actually offers several voices; with a
    // single voice we leave the default and let the pitch carry the difference.
    if (english.length == 1) {
      return null;
    }
    return english[(index - 1) % english.length];
  }

  bool _isEnglishVoice(Map<String, String> voice) {
    final String haystack = <String>[
      voice['locale'] ?? '',
      voice['name'] ?? '',
      voice['identifier'] ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains('en');
  }

  Future<void> _loadVoices() async {
    try {
      final Object? raw = await _tts.getVoices;
      if (raw is! List) {
        return;
      }
      final List<Map<String, String>> voices = <Map<String, String>>[];
      for (final Object? item in raw) {
        if (item is Map) {
          final Map<String, String> voice = <String, String>{};
          item.forEach((Object? key, Object? value) {
            if (key != null && value != null) {
              voice[key.toString()] = value.toString();
            }
          });
          if (voice.isNotEmpty) {
            voices.add(voice);
          }
        }
      }
      _voices = voices;
    } on Object catch (error, stackTrace) {
      appLogger.warning('TTS getVoices failed.', error, stackTrace);
      _voices = const <Map<String, String>>[];
    }
  }

  String _localeForAccent(String? accent) {
    switch ((accent ?? '').toLowerCase()) {
      case 'british':
      case 'uk':
      case 'en-gb':
        return 'en-GB';
      case 'american':
      case 'us':
      case 'en-us':
        return 'en-US';
      case 'australian':
      case 'au':
      case 'en-au':
        return 'en-AU';
      default:
        return 'en-US';
    }
  }
}

/// Provider for the shared TTS service. Disposed with the provider scope.
final Provider<ListeningTtsService> listeningTtsProvider =
    Provider<ListeningTtsService>((Ref ref) {
  final ListeningTtsService service = ListeningTtsService();
  ref.onDispose(service.dispose);
  return service;
});
