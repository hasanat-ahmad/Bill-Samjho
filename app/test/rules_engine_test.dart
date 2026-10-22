import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/core/i18n.dart';
import 'package:bill_samjho/data/models/bill.dart';
import 'package:bill_samjho/data/models/extracted_bill.dart';
import 'package:bill_samjho/data/models/finding.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:bill_samjho/domain/explanation_builder.dart';
import 'package:bill_samjho/domain/rules_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _asset(String name) =>
    jsonDecode(File('assets/$name').readAsStringSync()) as Map<String, dynamic>;

final config = TariffConfig.fromJson(_asset('tariff_config_default.json'));
final engine = RulesEngine(config);
final en = ExplanationBuilder(AppStrings(AppLanguage.en, _asset('i18n/en.json')));
final ur = ExplanationBuilder(AppStrings(AppLanguage.ur, _asset('i18n/ur.json')));

ExtractedBill bill({
  String month = '2026-09',
  int units = 150,
  double total = 3000,
  double? energy,
  double? arrears,
  double? fpa,
  double? qtr,
  int? previousReading,
  int? presentReading,
  List<HistoryEntry> history = const [],
  String? dueDate = '2026-10-15',
}) =>
    ExtractedBill(
      billMonth: month,
      units: units,
      totalDue: total,
      energyCharges: energy,
      arrears: arrears,
      fpa: fpa,
      qtrAdjustment: qtr,
      previousReading: previousReading,
      presentReading: presentReading,
      history: history,
      dueDate: dueDate,
    );

/// Six months (2026-03..2026-08) of the same [units].
List<HistoryEntry> flatHistory(int units) => [
      for (var m = 3; m <= 8; m++) HistoryEntry(month: '2026-0$m', units: units),
    ];

Bill saved(String month, int units) => Bill(
      id: month,
      connectionId: 'c1',
      data: bill(month: month, units: units),
      verdict: Verdict.normal,
      findings: const [],
      imagePath: '',
      createdAt: DateTime(2026),
    );

Set<String> rulesFired(ExtractedBill b, [List<Bill> past = const []]) =>
    engine.evaluate(b, past).findings.where((f) => !f.isSummary).map((f) => f.ruleId).toSet();

Finding finding(ExtractedBill b, String ruleId, [List<Bill> past = const []]) =>
    engine.evaluate(b, past).findings.firstWhere((f) => f.ruleId == ruleId);

void main() {
  group('energy slabs (S.R.O. 279(I)/2026)', () {
    test('protected: one previous slab benefit', () {
      expect(engine.computeEnergy(0, Tariff.protected), 0);
      expect(engine.computeEnergy(100, Tariff.protected), 1054.00);
      expect(engine.computeEnergy(101, Tariff.protected), 1067.01);
      expect(engine.computeEnergy(180, Tariff.protected), 2094.80);
      expect(engine.computeEnergy(200, Tariff.protected), 2355.00);
      expect(engine.computeEnergy(201, Tariff.protected), isNull);
    });

    test('non-protected: all units at the slab the total falls in', () {
      expect(engine.computeEnergy(0, Tariff.nonProtected), 0);
      expect(engine.computeEnergy(100, Tariff.nonProtected), 2244.00); // 100 × 22.44
      expect(engine.computeEnergy(101, Tariff.nonProtected), 2919.91); // 101 × 28.91
      expect(engine.computeEnergy(180, Tariff.nonProtected), 5203.80);
      expect(engine.computeEnergy(200, Tariff.nonProtected), 5782.00);
      expect(engine.computeEnergy(201, Tariff.nonProtected), 6653.10); // 201 × 33.10
      expect(engine.computeEnergy(300, Tariff.nonProtected), 9930.00);
      expect(engine.computeEnergy(301, Tariff.nonProtected), 10974.46); // 301 × 36.46
      expect(engine.computeEnergy(701, Tariff.nonProtected), 33087.20); // 701 × 47.20
    });

    test('lifeline: no slab benefit, only up to 100 units', () {
      expect(engine.computeEnergy(50, Tariff.lifeline), 197.50); // 50 × 3.95
      expect(engine.computeEnergy(51, Tariff.lifeline), 394.74); // 51 × 7.74
      expect(engine.computeEnergy(100, Tariff.lifeline), 774.00);
      expect(engine.computeEnergy(101, Tariff.lifeline), isNull);
    });
  });

  group('R1 energy check', () {
    test('fires when printed matches neither tariff', () {
      final f = finding(bill(units: 150, energy: 2500), 'R1');
      expect(f.severity, Severity.wrong);
      // Closest candidate is non-protected 3,689.50
      expect(f.params, {'expected': '3690', 'printed': '2500'});
      expect(en.findingText(f), contains('Rs 3,690'));
      expect(ur.findingText(f), contains('3,690 روپے'));
    });

    test('passes within tolerance of protected', () {
      expect(rulesFired(bill(units: 150, energy: 1704.5 * 1.02)), isNot(contains('R1')));
    });

    test('passes when matching non-protected (official or older method)', () {
      expect(rulesFired(bill(units: 150, energy: 4336.5)), isNot(contains('R1'))); // 150 × 28.91
      expect(rulesFired(bill(units: 150, energy: 3689.5)), isNot(contains('R1'))); // progressive
    });

    test('bills older than the current tariff are not checked', () {
      // April 2017 GEPCO bill: 50 units for Rs 100 was right at 2017 rates.
      expect(rulesFired(bill(month: '2017-04', units: 50, energy: 100)), isNot(contains('R1')));
      expect(rulesFired(bill(month: '2026-09', units: 50, energy: 100)), contains('R1'));
    });

    test('lifeline bills are not flagged', () {
      expect(rulesFired(bill(units: 40, energy: 158)), isNot(contains('R1'))); // 40 × 3.95
      expect(rulesFired(bill(units: 80, energy: 619.2)), isNot(contains('R1'))); // 80 × 7.74
    });

    test('above protected limit compares with non-protected only', () {
      expect(rulesFired(bill(units: 300, energy: 9930)), isNot(contains('R1')));
      expect(rulesFired(bill(units: 300, energy: 5000)), contains('R1'));
    });

    test('skipped when energy charges missing or units zero', () {
      expect(rulesFired(bill(units: 150)), isNot(contains('R1')));
      expect(rulesFired(bill(units: 0, energy: 500)), isNot(contains('R1')));
    });
  });

  group('R2 big jump', () {
    test('check when > 1.4 × average', () {
      final f = finding(bill(units: 150, history: flatHistory(100)), 'R2');
      expect(f.severity, Severity.check);
      expect(f.params['avg'], '100');
    });

    test('wrong when > 2 × average', () {
      expect(finding(bill(units: 201, history: flatHistory(100)), 'R2').severity, Severity.wrong);
    });

    test('does not fire at exactly 1.4 × average', () {
      expect(rulesFired(bill(units: 140, history: flatHistory(100))), isNot(contains('R2')));
    });

    test('does not fire without history', () {
      expect(rulesFired(bill(units: 500)), isNot(contains('R2')));
    });

    test('uses saved bills when bill has no history table', () {
      final past = [saved('2026-07', 100), saved('2026-08', 100)];
      expect(rulesFired(bill(units: 150), past), contains('R2'));
    });

    test('ignores months older than the window', () {
      final old = [HistoryEntry(month: '2025-12', units: 50)];
      expect(rulesFired(bill(units: 150, history: old)), isNot(contains('R2')));
    });
  });

  group('R3 same reading', () {
    test('fires when units equal last month', () {
      final history = [HistoryEntry(month: '2026-08', units: 150)];
      expect(finding(bill(units: 150, history: history), 'R3').severity, Severity.check);
    });

    test('fires when meter readings are equal but units > 0', () {
      expect(rulesFired(bill(units: 150, previousReading: 5000, presentReading: 5000)),
          contains('R3'));
    });

    test('does not fire for normal readings or different units', () {
      final history = [HistoryEntry(month: '2026-08', units: 149)];
      expect(
          rulesFired(bill(units: 150, previousReading: 5000, presentReading: 5150, history: history)),
          isNot(contains('R3')));
    });

    test('does not fire when only an older month matches', () {
      final history = [HistoryEntry(month: '2026-07', units: 150)];
      expect(rulesFired(bill(units: 150, history: history)), isNot(contains('R3')));
    });
  });

  group('R4 protected lost', () {
    test('fires when this month > 200, return month 6 months later', () {
      final f = finding(bill(units: 201), 'R4');
      expect(f.severity, Severity.check);
      expect(f.params['return_month'], '2027-03');
      expect(en.findingText(f), contains('March 2027'));
      expect(ur.findingText(f), contains('مارچ 2027'));
    });

    test('fires when a month in last 6 > 200', () {
      final history = [HistoryEntry(month: '2026-05', units: 210)];
      expect(finding(bill(units: 150, history: history), 'R4').params['return_month'], '2026-11');
    });

    test('fires from the bill\'s own "Unprotected" category without history', () {
      final unprotected = ExtractedBill(billMonth: '2026-09', units: 106, totalDue: 4367, protectedConsumer: false);
      final f = finding(unprotected, 'R4');
      expect(f.params['source'], 'bill');
      expect(en.findingText(f), contains('unprotected consumer'));
      expect(ur.findingText(f), contains('Unprotected'));
      final protected = ExtractedBill(billMonth: '2026-09', units: 106, totalDue: 4367, protectedConsumer: true);
      expect(rulesFired(protected), isNot(contains('R4')));
    });

    test('does not fire at exactly 200 or for months older than 6', () {
      expect(rulesFired(bill(units: 200)), isNot(contains('R4')));
      final history = [HistoryEntry(month: '2026-02', units: 300)];
      expect(rulesFired(bill(units: 150, history: history)), isNot(contains('R4')));
    });
  });

  group('R5 near limit', () {
    test('fires from 180 to 200 inclusive', () {
      expect(finding(bill(units: 180), 'R5').params, {'limit': '200', 'left': '20'});
      expect(finding(bill(units: 200), 'R5').severity, Severity.info);
    });

    test('does not fire at 179 or 201', () {
      expect(rulesFired(bill(units: 179)), isNot(contains('R5')));
      expect(rulesFired(bill(units: 201)), isNot(contains('R5')));
    });
  });

  group('R6 arrears', () {
    test('fires when arrears > 0', () {
      final f = finding(bill(arrears: 1250), 'R6');
      expect(f.severity, Severity.check);
      expect(f.params['arrears'], '1250');
      expect(en.findingText(f), contains('Rs 1,250'));
    });

    test('does not fire for zero or missing arrears', () {
      expect(rulesFired(bill(arrears: 0)), isNot(contains('R6')));
      expect(rulesFired(bill()), isNot(contains('R6')));
    });
  });

  group('R7 adjustments', () {
    test('fires for positive FPA or QTR', () {
      expect(finding(bill(fpa: 120), 'R7').severity, Severity.info);
      expect(rulesFired(bill(qtr: 30)), contains('R7'));
    });

    test('does not fire for zero, negative or missing', () {
      expect(rulesFired(bill(fpa: -50, qtr: 0)), isNot(contains('R7')));
      expect(rulesFired(bill()), isNot(contains('R7')));
    });
  });

  group('verdict', () {
    test('normal with no findings or only info', () {
      expect(engine.evaluate(bill(units: 120), const []).verdict, Verdict.normal);
      expect(engine.evaluate(bill(units: 190, fpa: 10), const []).verdict, Verdict.normal);
    });

    test('check beats info', () {
      expect(engine.evaluate(bill(units: 190, fpa: 10, arrears: 100), const []).verdict,
          Verdict.check);
    });

    test('wrong beats check', () {
      final result = engine.evaluate(bill(units: 150, energy: 9999, arrears: 100, fpa: 10), const []);
      expect(result.verdict, Verdict.wrong);
    });

    test('summary first, then wrong → check → info', () {
      final result = engine.evaluate(bill(units: 190, energy: 9999, arrears: 100, fpa: 10), const []);
      expect(result.findings.map((f) => f.ruleId), ['summary', 'R1', 'R6', 'R5', 'R7']);
      expect(en.findingText(result.findings.first), contains('used 190 units'));
      expect(en.findingText(result.findings.first), contains('15 October 2026'));
      expect(ur.findingText(result.findings.first), contains('15 اکتوبر 2026'));
    });
  });

  group('missing optional fields', () {
    test('minimal bill does not crash', () {
      final b = ExtractedBill.fromJson({'bill_month': '2026-09', 'units': 120, 'total_due': 1500});
      final result = engine.evaluate(b, const []);
      expect(result.verdict, Verdict.normal);
      expect(result.findings.single.isSummary, isTrue);
    });

    test('unparseable month, bad history and no due date do not crash', () {
      final b = ExtractedBill.fromJson({
        'bill_month': 'Sept',
        'units': '250',
        'total_due': '7,500',
        'history': [
          {'month': null, 'units': 10},
          {'month': 'Aug 26', 'units': 'abc'},
          'garbage',
        ],
      });
      expect(b.units, 250);
      expect(b.totalDue, 7500);
      final result = engine.evaluate(b, [saved('2026-08', 100)]);
      expect(result.findings.map((f) => f.ruleId), ['summary', 'R4']);
      for (final f in result.findings) {
        expect(en.findingText(f), isNot(contains('{')));
        expect(ur.findingText(f), isNot(contains('{')));
      }
    });
  });

  group('ExplanationBuilder', () {
    test('verdict sentence, summary, then findings, in both languages', () {
      final result = engine.evaluate(bill(units: 190, arrears: 100, fpa: 10), const []);
      final english = en.build(result.verdict, result.findings);
      expect(english, startsWith('A few things on your bill are worth checking.'));
      expect(english.indexOf('190'), lessThan(english.indexOf('unpaid amount')));
      final urdu = ur.build(result.verdict, result.findings);
      expect(urdu, startsWith(ur.verdictSentence(Verdict.check)));
      expect(urdu.indexOf('190'), lessThan(urdu.indexOf('بقایا')));
      expect('$english $urdu', isNot(contains('{')));
    });

    test('credit bill: nothing to pay, in both languages', () {
      final summary = engine.evaluate(bill(units: 50, total: -297), const []).findings.first;
      expect(en.findingText(summary), contains('credit of Rs 297'));
      expect(en.findingText(summary), contains('nothing to pay'));
      expect(ur.findingText(summary), contains('297 روپے کریڈٹ'));
    });

    test('every rule renders a full sentence in both languages', () {
      final all = engine.evaluate(
        bill(units: 250, energy: 99999, arrears: 100, fpa: 10, previousReading: 5, presentReading: 5, history: flatHistory(100)),
        const [],
      );
      expect(all.findings.map((f) => f.ruleId).toSet(), containsAll(['summary', 'R1', 'R2', 'R3', 'R4', 'R6', 'R7']));
      final near = engine.evaluate(bill(units: 190), const []).findings;
      for (final f in [...all.findings, ...near]) {
        for (final b in [en, ur]) {
          final text = b.findingText(f);
          expect(text, isNot(contains('{')), reason: '${f.ruleId} ${b.s.language}');
          expect(text, isNot(startsWith('r')), reason: 'template key leaked for ${f.ruleId}');
          expect(text.length, greaterThan(20));
        }
      }
    });

    test('complaint uses reference, month, units and worst finding', () {
      final data = ExtractedBill(
        billMonth: '2026-09',
        units: 150,
        totalDue: 3000,
        energyCharges: 2500,
        referenceNo: '12 34567 1234567',
      );
      final result = engine.evaluate(data, const []);
      final saved = Bill(
        id: '1',
        connectionId: 'c1',
        data: data,
        verdict: result.verdict,
        findings: result.findings,
        imagePath: '',
        createdAt: DateTime(2026),
      );
      final english = en.complaint(saved);
      expect(english, contains('12 34567 1234567'));
      expect(english, contains('September 2026'));
      expect(english, contains('Rs 2,500'));
      final urdu = ur.complaint(saved);
      expect(urdu, contains('ستمبر 2026'));
      expect('$english $urdu', isNot(contains('{')));
    });
  });
}
