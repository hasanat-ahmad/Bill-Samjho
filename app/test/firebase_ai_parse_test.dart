import 'dart:convert';

import 'package:bill_samjho/data/api_service.dart';
import 'package:bill_samjho/data/firebase_ai_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _out([Map<String, dynamic> overrides = const {}]) => jsonEncode({
      'is_electricity_bill': true,
      'confidence': 0.95,
      'bill_month': '2026-09',
      'units': 106,
      'total_due': 4367,
      'previous_reading': 249,
      'present_reading': 355,
      'history': [],
      ...overrides,
    });

Matcher _apiError(ApiError e) => throwsA(isA<ApiException>().having((x) => x.error, 'error', e));

void main() {
  test('valid model output becomes a bill', () {
    final b = FirebaseAiApiService.parseModelOutput(_out({'protected_consumer': false}));
    expect(b.units, 106);
    expect(b.totalDue, 4367);
    expect(b.confidence, 0.95);
    expect(b.protectedConsumer, isFalse);
  });

  test('not a bill, low confidence, garbage and missing fields are rejected', () {
    expect(() => FirebaseAiApiService.parseModelOutput(_out({'is_electricity_bill': false})), _apiError(ApiError.notABill));
    expect(() => FirebaseAiApiService.parseModelOutput(_out({'confidence': 0.4})), _apiError(ApiError.unreadable));
    expect(() => FirebaseAiApiService.parseModelOutput('not json'), _apiError(ApiError.unreadable));
    expect(() => FirebaseAiApiService.parseModelOutput(_out({'units': null})), _apiError(ApiError.unreadable));
  });

  test('readings that do not add up lower confidence so the user checks closely', () {
    expect(FirebaseAiApiService.parseModelOutput(_out({'present_reading': 400})).confidence, 0.6);
    expect(
      FirebaseAiApiService.parseModelOutput(_out({'previous_reading': 100, 'present_reading': 153, 'meter_multiplier': 2})).confidence,
      0.95,
    );
  });

  test('credit bill is accepted', () {
    expect(FirebaseAiApiService.parseModelOutput(_out({'total_due': -297})).isCredit, isTrue);
  });

  test('setup errors are recognised so users are not told to retry', () {
    expect(FirebaseAiApiService.isSetupError('Firebase AI Logic API has not been used in project 1 before or it is disabled.'), isTrue);
    expect(FirebaseAiApiService.isSetupError('PERMISSION_DENIED'), isTrue);
    expect(FirebaseAiApiService.isSetupError('The model is overloaded. Please try again later.'), isFalse);
  });

  // QA D-02: a confidence written as text is read like the server reads it,
  // not mistaken for "AI busy" (which retried every model).
  test('numbers written as text: read like the server; NaN is unreadable', () {
    expect(FirebaseAiApiService.parseModelOutput(_out({'confidence': '0.9'})).confidence, 0.9);
    expect(() => FirebaseAiApiService.parseModelOutput(_out({'confidence': 'NaN'})), _apiError(ApiError.unreadable));
    expect(FirebaseAiApiService.parseModelOutput(_out({'present_reading': '355'})).presentReading, 355);
  });
}
