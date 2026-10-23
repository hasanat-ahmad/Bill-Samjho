import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/core/i18n.dart';
import 'package:bill_samjho/data/bill_chat.dart';
import 'package:bill_samjho/features/chat/chat_cubit.dart';
import 'package:bill_samjho/features/chat/chat_screen.dart';
import 'package:bill_samjho/services/dictation_service.dart';
import 'package:bill_samjho/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

/// Records questions; answers at once.
class EchoChat implements BillChat {
  final asked = <String>[];

  @override
  bool get atLimit => false;

  @override
  Stream<String> ask(String question) async* {
    asked.add(question);
    yield 'Answer.';
  }
}

/// Lets the test speak words, fail, or go quiet.
class FakeDictation implements Dictation {
  AppLanguage? language;
  void Function(String, bool)? _onText;
  void Function(DictationError)? _onError;
  void Function()? _onEnd;
  bool stopped = false, cancelled = false;

  @override
  Future<void> start({
    required AppLanguage language,
    required void Function(String text, bool done) onText,
    required void Function(DictationError error) onError,
    required void Function() onEnd,
    void Function(double level)? onLevel,
  }) async {
    this.language = language;
    _onText = onText;
    _onError = onError;
    _onEnd = onEnd;
    onLevel?.call(5);
  }

  void say(String words, {bool done = false}) => _onText!(words, done);
  void fail(DictationError e) => _onError!(e);
  void end() => _onEnd!();

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> cancel() async => cancelled = true;
}

void main() {
  final en = AppStrings(AppLanguage.en, _json('assets/i18n/en.json'));
  final ur = AppStrings(AppLanguage.ur, _json('assets/i18n/ur.json'));

  Future<EchoChat> pumpChat(WidgetTester tester, Dictation? dictation, {AppStrings? strings}) async {
    final chat = EchoChat();
    final s = strings ?? en;
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: TtsService()),
        RepositoryProvider<Dictation?>.value(value: dictation),
        RepositoryProvider<AppStrings>.value(value: s),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: s.language.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: BlocProvider(create: (_) => ChatCubit(chat), child: const ChatScreen(billMonth: '2026-09')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return chat;
  }

  testWidgets('speaking fills the box live; the user checks it, then sends', (tester) async {
    final mic = FakeDictation();
    final chat = await pumpChat(tester, mic);

    // Empty box: the mic is offered instead of send.
    expect(find.byTooltip('Speak your question'), findsOneWidget);
    expect(find.byTooltip('Send'), findsNothing);

    await tester.tap(find.byTooltip('Speak your question'));
    await tester.pump();
    expect(mic.language, AppLanguage.en);
    expect(find.byTooltip('Stop listening'), findsOneWidget);
    expect(find.text('Listening… speak now'), findsOneWidget);

    mic.say('What is');
    await tester.pump();
    expect(find.text('What is'), findsOneWidget);

    mic.say('What is FPA', done: true);
    await tester.pumpAndSettle();
    expect(find.text('What is FPA'), findsOneWidget);
    expect(chat.asked, isEmpty); // not sent until the user taps send

    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chat.asked, ['What is FPA']);
    expect(find.byTooltip('Speak your question'), findsOneWidget); // box empty again
  });

  testWidgets('a late result after sending does not refill the box', (tester) async {
    final mic = FakeDictation();
    final chat = await pumpChat(tester, mic);

    await tester.tap(find.byTooltip('Speak your question'));
    await tester.pump();
    mic.say('What is FPA');
    mic.end(); // the phone stops listening after a pause
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chat.asked, ['What is FPA']);

    // The recognizer re-sends its last words as "final" about 2 s later.
    mic.say('What is FPA', done: true);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.byTooltip('Speak your question'), findsOneWidget);
  });

  testWidgets('spoken words are added after typed ones; tapping stop ends listening', (tester) async {
    final mic = FakeDictation();
    await pumpChat(tester, mic);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    expect(find.byTooltip('Send'), findsOneWidget); // text present: send, not mic

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.byTooltip('Speak your question'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop listening'));
    await tester.pump();
    expect(mic.stopped, isTrue);
    mic.end();
    await tester.pump();
    expect(find.byTooltip('Speak your question'), findsOneWidget);
  });

  testWidgets('errors explain what to do', (tester) async {
    final mic = FakeDictation();
    await pumpChat(tester, mic);

    await tester.tap(find.byTooltip('Speak your question'));
    await tester.pump();
    mic.fail(DictationError.permission);
    await tester.pump();
    expect(find.textContaining('allow the microphone'), findsOneWidget);
    expect(find.byTooltip('Speak your question'), findsOneWidget); // back to idle
  });

  testWidgets('Urdu app listens in Urdu', (tester) async {
    final mic = FakeDictation();
    await pumpChat(tester, mic, strings: ur);
    await tester.tap(find.byTooltip('اپنا سوال بول کر پوچھیں'));
    await tester.pump();
    expect(mic.language, AppLanguage.ur);
  });

  testWidgets('no dictation: no mic, and no voice privacy note', (tester) async {
    await pumpChat(tester, null);
    expect(find.byTooltip('Speak your question'), findsNothing);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.textContaining("speech service"), findsNothing);
  });

  test('listens in Urdu (Pakistan) or the phone\'s own English', () {
    expect(SpeechDictation.localeFor(AppLanguage.ur, 'en-US'), 'ur-PK');
    expect(SpeechDictation.localeFor(AppLanguage.en, 'en-GB'), isNull); // phone default
    expect(SpeechDictation.localeFor(AppLanguage.en, 'ur-PK'), 'en-US');
  });

  test('recognizer error codes map to actionable messages', () {
    expect(dictationErrorFor('error_no_match'), DictationError.noSpeech);
    expect(dictationErrorFor('error_speech_timeout'), DictationError.noSpeech);
    expect(dictationErrorFor('error_network'), DictationError.network);
    expect(dictationErrorFor('error_language_unavailable'), DictationError.language);
    expect(dictationErrorFor('error_permission'), DictationError.permission);
    expect(dictationErrorFor('error_busy'), DictationError.other);
    for (final e in DictationError.values) {
      expect(en.t('dictate_${e.name}'), isNot('dictate_${e.name}'));
      expect(ur.t('dictate_${e.name}'), isNot('dictate_${e.name}'));
    }
  });
}
