import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/core/i18n.dart';
import 'package:bill_samjho/data/bill_chat.dart';
import 'package:bill_samjho/data/models/bill.dart';
import 'package:bill_samjho/data/models/extracted_bill.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:bill_samjho/domain/chat_prompt.dart';
import 'package:bill_samjho/domain/forecaster.dart';
import 'package:bill_samjho/domain/rules_engine.dart';
import 'package:bill_samjho/features/chat/chat_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

/// Answers word by word, or fails as told.
class FakeChat implements BillChat {
  FakeChat({this.fail, this.answer = 'Your bill is Rs 4,367.'});
  BillChatException? fail;
  final String answer;
  int asked = 0;

  @override
  bool get atLimit => asked >= 2;

  @override
  Stream<String> ask(String question) async* {
    if (fail != null) throw fail!;
    var text = '';
    for (final word in answer.split(' ')) {
      text = text.isEmpty ? word : '$text $word';
      yield text;
    }
    asked++;
  }
}

void main() {
  final config = TariffConfig.fromJson(_json('assets/tariff_config_default.json'));
  final en = AppStrings(AppLanguage.en, _json('assets/i18n/en.json'));
  final ur = AppStrings(AppLanguage.ur, _json('assets/i18n/ur.json'));
  const data = ExtractedBill(
    billMonth: '2026-09',
    units: 106,
    totalDue: 4367,
    dueDate: '2026-10-14',
    disco: 'PESCO',
    protectedConsumer: false,
    fpa: 0,
  );
  final result = RulesEngine(config).evaluate(data, const []);
  final bill = Bill(
    id: 'b',
    connectionId: 'c',
    data: data,
    verdict: result.verdict,
    findings: result.findings,
    imagePath: '',
    createdAt: DateTime(2026),
  );

  group('chat prompt', () {
    test('contains the bill numbers, findings, estimate, tariff and rules', () {
      final p = buildChatPrompt(
        s: en,
        bill: bill,
        config: config,
        forecast: Forecaster(config).forecast(data, const []),
        nickname: 'Home',
      );
      expect(p, contains('Units used: 106'));
      expect(p, contains('Rs 4,367'));
      expect(p, contains('14 October 2026'));
      expect(p, contains('Unprotected'));
      expect(p, contains('unprotected consumer')); // R4 finding from the bill category
      expect(p, contains('may be about 106 units'));
      expect(p, contains('120 units: about Rs'));
      expect(p, contains('no asterisks'));
      expect(p, contains('36.46')); // tariff from config
      expect(p, contains('Never invent numbers'));
      expect(p, contains('simple English'));
      expect(p, contains('FPA (Fuel Price Adjustment)'));
    });

    test('asks for Urdu when the app is in Urdu', () {
      final p = buildChatPrompt(s: ur, bill: bill, config: config);
      expect(p, contains('Reply in Urdu'));
      expect(p, contains('ستمبر 2026'));
    });
  });

  test('answers are shown as plain text', () {
    expect(plainAnswer('Tips:\n- **Keep under 200 units:** saves money\n* Pay on time\n## Note'),
        'Tips:\n• Keep under 200 units: saves money\n• Pay on time\nNote');
  });

  group('chat cubit', () {
    test('streams the answer after the question', () async {
      final cubit = ChatCubit(FakeChat());
      await cubit.ask('Why?');
      expect(cubit.state.messages.map((m) => m.fromUser), [true, false]);
      expect(cubit.state.messages.last.text, 'Your bill is Rs 4,367.');
      expect(cubit.state.busy, isFalse);
    });

    test('a failed answer marks the question for retry', () async {
      final chat = FakeChat(fail: const BillChatException());
      final cubit = ChatCubit(chat);
      await cubit.ask('Why?');
      expect(cubit.state.messages.single.failed, isTrue);
      expect(cubit.state.unavailable, isFalse);
      chat.fail = null;
      await cubit.retry();
      expect(cubit.state.messages.map((m) => m.failed), [false, false]);
    });

    test('setup problems switch the chat to unavailable', () async {
      final cubit = ChatCubit(FakeChat(fail: const BillChatException(setup: true)));
      await cubit.ask('Why?');
      expect(cubit.state.unavailable, isTrue);
    });

    test('limit on questions per chat', () async {
      final cubit = ChatCubit(FakeChat());
      await cubit.ask('1');
      await cubit.ask('2');
      expect(cubit.state.atLimit, isTrue);
      await cubit.ask('3');
      expect(cubit.state.messages.where((m) => m.fromUser), hasLength(2));
    });

    test('empty questions are ignored', () async {
      final cubit = ChatCubit(FakeChat());
      await cubit.ask('   ');
      expect(cubit.state.messages, isEmpty);
    });
  });
}
