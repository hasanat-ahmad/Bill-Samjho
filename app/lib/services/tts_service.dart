import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/i18n.dart';
import 'speech_text.dart';

/// Text-to-speech in the app language (FR-10). [playing] holds the ID of the
/// text being spoken so each play button can show its own state.
///
/// Phones often report a language as installed while its default voice is
/// broken (e.g. Google's neural Urdu voice failing with error -4), so this
/// picks voices explicitly and falls back to the next voice until one
/// actually starts speaking.
///
/// Offline only: Google's engine lists each voice twice, "-local" (made on
/// the phone, a neural voice on current versions) and "-network" (made on
/// Google's servers). Only the local ones are used, so nothing is sent, and
/// one voice per language is kept so it never changes mid-explanation. Text
/// is rewritten for speech first ([SpeechText]).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<String?> playing = ValueNotifier(null);

  /// Increments when no voice could speak, so the UI can tell the user.
  final ValueNotifier<int> failures = ValueNotifier(0);

  /// False when the phone lists no voice for the current language; the text
  /// is always shown anyway.
  bool voiceAvailable = false;

  static const _startTimeout = Duration(seconds: 4);

  AppLanguage _language = AppLanguage.en;
  bool _slow = false;

  /// Voices for the current language, best first. Empty when the engine
  /// cannot list voices; then the language is set the legacy way.
  List<Map<String, String>> _voices = const [];
  int _voiceIndex = 0;

  /// Language setup in progress; speaking waits for it.
  Future<void> _ready = Future.value();
  int _generation = 0;

  /// Completes true when the current utterance starts, false on error or a
  /// silent finish.
  Completer<bool>? _started;

  /// True between the engine's start and done/cancel callbacks. Callbacks
  /// from a failed attempt must not end a fallback in progress.
  bool _speaking = false;

  Future<void> init({required AppLanguage language, required bool slow}) async {
    _slow = slow;
    try {
      await _tts.awaitSpeakCompletion(false);
      _tts.setStartHandler(() {
        _speaking = true;
        _complete(true);
      });
      void finished() {
        _complete(false);
        if (_speaking) playing.value = null;
        _speaking = false;
      }

      _tts.setCompletionHandler(finished);
      _tts.setCancelHandler(finished);
      _tts.setErrorHandler((message) {
        debugPrint('TTS error: $message');
        _complete(false);
      });
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
    await setLanguage(language);
  }

  AppLanguage get language => _language;

  /// Selects voices for [language]. Calls are serialised: a newer call wins
  /// even if an older, slower one finishes later.
  Future<void> setLanguage(AppLanguage language) {
    _language = language;
    final generation = ++_generation;
    _ready = _ready.then((_) => _configure(language, generation)).catchError((Object e) {
      debugPrint('TTS language setup failed: $e');
    });
    return _ready;
  }

  Future<void> _configure(AppLanguage language, int generation) async {
    if (generation != _generation) return;
    await _safely(_tts.stop);
    playing.value = null;
    final voices = await _voicesFor(language);
    if (generation != _generation) return;
    _voices = voices;
    _voiceIndex = 0;
    if (voices.isNotEmpty) {
      voiceAvailable = true;
    } else {
      voiceAvailable = await _setLegacyLanguage(language);
    }
    debugPrint('TTS ${language.name}: ${voices.length} voices, available=$voiceAvailable');
    await _safely(() => _tts.setSpeechRate(_slow ? _rateSlow : _rateNormal));
  }

  /// Android's normal speaking speed is 0.5; slower sounds unnatural.
  static const _rateNormal = 0.5;
  static const _rateSlow = 0.36;

  /// Offline voices for [language]: preferred locale first (ur-PK before
  /// ur-IN), then by name, so the same voice is chosen every time.
  Future<List<Map<String, String>>> _voicesFor(AppLanguage language) async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];
      final wanted = language.ttsLocales.map((l) => l.toLowerCase()).toList();
      final voices = <Map<String, String>>[];
      for (final v in raw) {
        if (v is! Map) continue;
        final name = '${v['name'] ?? ''}';
        final locale = '${v['locale'] ?? ''}';
        if (name.isEmpty || !wanted.contains(locale.toLowerCase())) continue;
        voices.add({'name': name, 'locale': locale, 'network': '${v['network_required'] ?? '0'}'});
      }
      return offlineVoices(voices, wanted);
    } catch (e) {
      debugPrint('TTS voice list failed: $e');
      return const [];
    }
  }

  /// Keeps only voices that work without internet ("-local", not "-network",
  /// and not the "...-language" alias for one of them), in a fixed order.
  @visibleForTesting
  static List<Map<String, String>> offlineVoices(List<Map<String, String>> voices, List<String> locales) {
    final out = voices
        .where((v) => v['network'] != '1' && !v['name']!.endsWith('-network') && !v['name']!.endsWith('-language'))
        .toList();
    int rank(Map<String, String> v) => locales.indexOf(v['locale']!.toLowerCase());
    out.sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a['name']!.compareTo(b['name']!));
    return out;
  }

  Future<bool> _setLegacyLanguage(AppLanguage language) async {
    for (final locale in language.ttsLocales) {
      try {
        if (await _tts.isLanguageAvailable(locale) == true) {
          await _tts.setLanguage(locale);
          return true;
        }
      } catch (e) {
        debugPrint('TTS language check failed: $e');
        return false;
      }
    }
    return false;
  }

  Future<void> setSlow(bool slow) {
    _slow = slow;
    return _safely(() => _tts.setSpeechRate(slow ? _rateSlow : _rateNormal));
  }

  /// Speaks [text], trying the next voice whenever one fails to start.
  Future<void> speak(String id, String text) async {
    playing.value = id;
    await _ready;
    text = SpeechText.prepare(text, _language);
    final attempts = _voices.isEmpty ? 1 : _voices.length;
    for (var i = 0; i < attempts; i++) {
      if (playing.value != id) return; // stopped or replaced meanwhile
      final index = (_voiceIndex + i) % attempts;
      if (_voices.isNotEmpty) {
        final v = _voices[index];
        await _safely(() => _tts.setVoice({'name': v['name']!, 'locale': v['locale']!}));
      }
      if (await _speakOnce(text)) {
        _voiceIndex = index; // remember the voice that works
        return;
      }
      debugPrint('TTS voice ${_voices.isEmpty ? 'default' : _voices[index]['name']} failed, trying next');
    }
    if (playing.value == id) {
      playing.value = null;
      failures.value++;
    }
  }

  Future<bool> _speakOnce(String text) async {
    final started = _started = Completer<bool>();
    _speaking = false;
    try {
      // speak() flushes anything queued before it.
      final result = await _tts.speak(text);
      if (result != 1) return false;
      return await started.future.timeout(_startTimeout, onTimeout: () => false);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      return false;
    }
  }

  void _complete(bool started) {
    final c = _started;
    if (c != null && !c.isCompleted) c.complete(started);
  }

  /// Play [text], or stop it if [id] is already playing.
  Future<void> toggle(String id, String text) => playing.value == id ? stop() : speak(id, text);

  Future<void> stop() async {
    playing.value = null;
    _speaking = false;
    _complete(false);
    await _safely(_tts.stop);
  }

  /// A broken TTS engine must never crash the app; the text is always shown.
  Future<void> _safely(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }
}
