import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/i18n.dart';

/// Text-to-speech in the app language (FR-10). [playing] holds the ID of the
/// text being spoken so each play button can show its own state.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<String?> playing = ValueNotifier(null);

  /// False when the phone has no voice for the current language; the text
  /// is always shown anyway.
  bool voiceAvailable = false;

  AppLanguage _language = AppLanguage.en;
  bool _slow = false;

  Future<void> init({required AppLanguage language, required bool slow}) async {
    try {
      await _tts.awaitSpeakCompletion(false);
      void done() => playing.value = null;
      _tts.setCompletionHandler(done);
      _tts.setCancelHandler(done);
      _tts.setErrorHandler((_) => done());
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
    await setLanguage(language);
    await setSlow(slow);
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    voiceAvailable = false;
    await stop();
    for (final locale in language.ttsLocales) {
      try {
        if (await _tts.isLanguageAvailable(locale) == true) {
          await _tts.setLanguage(locale);
          voiceAvailable = true;
          break;
        }
      } catch (e) {
        debugPrint('TTS language check failed: $e');
        break;
      }
    }
    // Rate depends on the voice; reapply it.
    await setSlow(_slow);
  }

  AppLanguage get language => _language;

  Future<void> setSlow(bool slow) {
    _slow = slow;
    return _safely(() => _tts.setSpeechRate(slow ? 0.32 : 0.47));
  }

  Future<void> speak(String id, String text) async {
    playing.value = id;
    await _safely(() async {
      await _tts.stop();
      await _tts.speak(text);
    });
  }

  /// Play [text], or stop it if [id] is already playing.
  Future<void> toggle(String id, String text) => playing.value == id ? stop() : speak(id, text);

  Future<void> stop() async {
    playing.value = null;
    await _safely(_tts.stop);
  }

  /// A broken TTS engine must never crash the app; the text is always shown.
  Future<void> _safely(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('TTS error: $e');
      playing.value = null;
    }
  }
}
