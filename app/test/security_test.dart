import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bill_samjho/data/api_service.dart';
import 'package:bill_samjho/data/models/extracted_bill.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _defaultTariff() =>
    jsonDecode(File('assets/tariff_config_default.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _bill([Map<String, dynamic> overrides = const {}]) =>
    {...MockApiService.sampleBillJson, ...overrides};

void main() {
  group('backend response is untrusted (NFR-09)', () {
    test('valid sample is accepted', () {
      final b = ExtractedBill.fromUntrusted(_bill());
      expect(b.units, 186);
      expect(b.history, hasLength(6));
    });

    test('required fields missing or out of range are rejected', () {
      for (final bad in <Map<String, dynamic>>[
        {'units': null},
        {'units': -1},
        {'units': 5001},
        {'total_due': null},
        {'total_due': -1e12},
        {'total_due': 1e12},
        {'total_due': double.nan},
        {'bill_month': null},
        {'bill_month': 'September'},
        {'bill_month': '2026-13'},
      ]) {
        expect(() => ExtractedBill.fromUntrusted(_bill(bad)), throwsFormatException, reason: '$bad');
      }
    });

    test('text is capped and stripped of control and bidi-override characters', () {
      final b = ExtractedBill.fromUntrusted(_bill({
        'reference_no': '07\u202E11234\u0000${'9' * 200}',
        'disco': '\u2066LESCO\u2069',
      }));
      expect(b.referenceNo, isNot(contains('\u202E')));
      expect(b.referenceNo, isNot(contains('\u0000')));
      expect(b.referenceNo!.length, 40);
      expect(b.disco, 'LESCO');
    });

    test('bad optional values are dropped, not trusted', () {
      final b = ExtractedBill.fromUntrusted(_bill({
        'arrears': 1e15,
        'due_date': '15th October',
        'present_reading': -5,
        'confidence': 7,
        'history': [
          {'month': 'Aug', 'units': 100},
          {'month': '2026-08', 'units': 99999},
          ...List.generate(40, (i) => {'month': '2025-01', 'units': i}),
        ],
      }));
      expect(b.arrears, isNull);
      expect(b.dueDate, isNull);
      expect(b.presentReading, isNull);
      expect(b.confidence, 1.0);
      expect(b.history.length, ExtractedBill.maxHistoryRows);
      expect(b.history.every((h) => h.month == '2025-01'), isTrue);
    });

    test('credit bill (negative total) is accepted', () {
      final b = ExtractedBill.fromUntrusted(_bill({'total_due': -297}));
      expect(b.totalDue, -297);
      expect(b.isCredit, isTrue);
    });

    test('history that is not a list is ignored', () {
      expect(ExtractedBill.fromUntrusted(_bill({'history': 'oops'})).history, isEmpty);
    });

    // QA D-01: dates and months are stored in the one form the rest of the app reads.
    test('dates and months are normalised; impossible dates are dropped', () {
      final b = ExtractedBill.fromUntrusted(_bill({
        'bill_month': '2026-9',
        'due_date': '2026-10-5',
        'reading_date': '2026-02-31',
        'history': [
          {'month': '2026-8', 'units': 178},
        ],
      }));
      expect(b.billMonth, '2026-09');
      expect(b.dueDate, '2026-10-05');
      expect(b.readingDate, isNull); // 31 February
      expect(b.history.single.month, '2026-08');
    });

    // QA D-02: "NaN" and "Infinity" are not numbers a bill can contain.
    test('non-finite numbers are rejected, never trusted', () {
      expect(() => ExtractedBill.fromUntrusted(_bill({'units': 'Infinity'})), throwsFormatException);
      expect(() => ExtractedBill.fromUntrusted(_bill({'total_due': 'NaN'})), throwsFormatException);
      final b = ExtractedBill.fromUntrusted(_bill({
        'confidence': 'NaN',
        'gst': double.infinity,
        'history': [
          {'month': '2026-08', 'units': 178, 'amount': double.infinity},
          {'month': '2026-07', 'units': 212, 'amount': 1e15},
        ],
      }));
      expect(b.confidence, 0); // not 1.0
      expect(b.gst, isNull);
      expect(b.history.map((h) => h.amount), [null, null]);
    });
  });

  group('remote tariff config is range-checked', () {
    test('bundled default is valid', () {
      expect(() => TariffConfig.fromJson(_defaultTariff()), returnsNormally);
    });

    test('nonsense values are rejected so the previous config stays', () {
      final cases = <void Function(Map<String, dynamic>)>[
        (j) => j['protected_limit_units'] = 0,
        (j) => j['near_limit_units'] = 500,
        (j) => j['energy_tolerance_percent'] = 90,
        (j) => (j['slabs']['protected'] as List).first['rate'] = 0,
        (j) => (j['slabs']['non_protected'] as List).first['rate'] = 99999,
        (j) => (j['slabs']['protected'] as List).first['to'] = 0,
        (j) => j['slabs']['protected'] = <Object>[],
      ];
      for (final mutate in cases) {
        final json = _defaultTariff();
        mutate(json);
        expect(() => TariffConfig.fromJson(json), throwsA(isA<Object>()));
      }
    });
  });

  group('API client', () {
    test('backend must be HTTPS; plain HTTP only to the local emulator in debug', () {
      expect(isAllowedBackend(Uri.parse('https://x.cloudfunctions.net/extractBill'), release: true), isTrue);
      expect(isAllowedBackend(Uri.parse('http://x.cloudfunctions.net/extractBill'), release: true), isFalse);
      expect(isAllowedBackend(Uri.parse('http://10.0.2.2:5001/p/r/extractBill'), release: true), isFalse);
      expect(isAllowedBackend(Uri.parse('http://10.0.2.2:5001/p/r/extractBill'), release: false), isTrue);
      expect(isAllowedBackend(Uri.parse('http://192.168.1.5:5001/x'), release: false), isFalse);
    });

    test('mock is never used silently: it reports itself as demo', () {
      expect(MockApiService().isMock, isTrue);
      expect(UnavailableApiService().isMock, isFalse);
    });

    test('unavailable service fails with a clear error', () async {
      await expectLater(
        UnavailableApiService().extractBill(Uint8List(0), 'id'),
        throwsA(isA<ApiException>().having((e) => e.error, 'error', ApiError.unavailable)),
      );
    });
  });
}
