import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/i18n.dart';

/// Why voice typing stopped without text. Each has its own message.
enum DictationError { permission, unavailable, noSpeech, network, language, other }

/// Voice typing for the chat: speech in the app language becomes text the
/// user can check before sending.
abstract class Dictation {
  /// Starts listening. [onText] gets the words so far ([done] on the last
  /// call); [onError] ends the session without text; [onEnd] is called when
  /// the microphone closes for any reason.
  Future<void> start({
    required AppLanguage language,
    required void Function(String text, bool done) onText,
    required void Function(DictationError error) onError,
    required void Function() onEnd,
    void Function(double level)? onLevel,
  });

  /// Stops and delivers what was heard.
  Future<void> stop();

  /// Stops and drops what was heard.
  Future<void> cancel();
}

/// The phone's speech recognizer (Google on most Android phones). The
/// microphone permission is asked on first use, not at app start.
class SpeechDictation implements Dictation {
  final SpeechToText _speech = SpeechToText();
  void Function(DictationError)? _onError;
  void Function()? _onEnd;
  bool _gotText = false;

  @override
  Future<void> start({
    required AppLanguage language,
    required void Function(String text, bool done) onText,
    required void Function(DictationError error) onError,
    required void Function() onEnd,
    void Function(double level)? onLevel,
  }) async {
    _onError = onError;
    _onEnd = onEnd;
    _gotText = false;
    final bool ready;
    try {
      ready = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        // Only the microphone; no Bluetooth permission needed. Not
        // androidIntentLookup: it picks the first recognizer installed, often
        // the on-device one without language packs (error 13).
        options: [SpeechToText.androidNoBluetooth],
      );
    } catch (e) {
      debugPrint('Dictation init failed: ${e.runtimeType}');
      onError(DictationError.unavailable);
      return onEnd();
    }
    if (!ready) {
      onError(await _speech.hasPermission ? DictationError.unavailable : DictationError.permission);
      return onEnd();
    }
    try {
      await _speech.listen(
        onResult: (r) {
          if (r.recognizedWords.isNotEmpty) _gotText = true;
          onText(r.recognizedWords, r.finalResult);
        },
        onSoundLevelChange: onLevel,
        listenOptions: SpeechListenOptions(
          localeId: localeFor(language, PlatformDispatcher.instance.locale.toLanguageTag()),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Dictation listen failed: ${e.runtimeType}');
      onError(DictationError.other);
      onEnd();
    }
  }

  /// The recognizer's language. Not looked up with locales(): on Android 13+
  /// that call can wait forever when on-device recognition is missing.
  /// English uses the phone's own English if it has one (e.g. en-GB).
  static String? localeFor(AppLanguage language, String deviceLocale) => switch (language) {
        AppLanguage.ur => 'ur-PK',
        AppLanguage.en => deviceLocale.toLowerCase().startsWith('en') ? null : 'en-US',
      };

  void _handleError(SpeechRecognitionError e) {
    debugPrint('Dictation error: ${e.errorMsg}');
    if (!e.permanent && _gotText) return;
    _onError?.call(dictationErrorFor(e.errorMsg));
  }

  void _handleStatus(String status) {
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _onEnd?.call();
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

/// Maps the recognizer's error codes to what the user can act on.
@visibleForTesting
DictationError dictationErrorFor(String code) => switch (code) {
      'error_no_match' || 'error_speech_timeout' => DictationError.noSpeech,
      'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' =>
        DictationError.network,
      'error_language_not_supported' || 'error_language_unavailable' => DictationError.language,
      'error_permission' || 'error_insufficient_permissions' => DictationError.permission,
      _ => DictationError.other,
    };
