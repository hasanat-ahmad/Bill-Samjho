import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Urdu text-to-speech (FR-10). [playing] holds the ID of the text being
/// spoken so each play button can show its own state.
class TtsService {
  static const _language = 'ur-PK';

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<String?> playing = ValueNotifier(null);

  /// False when the phone has no Urdu voice; the text is still shown.
  bool urduAvailable = false;

  Future<void> init({required bool slow}) async {
    try {
      urduAvailable = await _tts.isLanguageAvailable(_language) == true;
      if (urduAvailable) await _tts.setLanguage(_language);
      await _tts.awaitSpeakCompletion(false);
      await setSlow(slow);
      void done() => playing.value = null;
      _tts.setCompletionHandler(done);
      _tts.setCancelHandler(done);
      _tts.setErrorHandler((_) => done());
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> setSlow(bool slow) => _safely(() => _tts.setSpeechRate(slow ? 0.3 : 0.45));

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
