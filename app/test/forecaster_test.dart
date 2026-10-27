import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/data/models/bill.dart';
import 'package:bill_samjho/data/models/extracted_bill.dart';
import 'package:bill_samjho/data/models/finding.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:bill_samjho/domain/forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

final config = TariffConfig.fromJson(
  jsonDecode(File('assets/tariff_config_default.json').readAsStringSync()) as Map<String, dynamic>,
);
final forecaster = Forecaster(config);

ExtractedBill bill({
  String month = '2026-09',
  int units = 100,
  double total = 3000,
  List<HistoryEntry> history = const [],
  int? present,
  String? readingDate,
  String? dueDate,
  double? arrears,
  bool? protectedConsumer,
}) =>
    ExtractedBill(
      billMonth: month,
      units: units,
      totalDue: total,
      history: history,
      presentReading: present,
      readingDate: readingDate,
      dueDate: dueDate,
      arrears: arrears,
      protectedConsumer: protectedConsumer,
    );

Bill saved(String month, int units) => Bill(
      id: month,
      connectionId: 'c',
      data: bill(month: month, units: units),
      verdict: Verdict.normal,
      findings: const [],
      imagePath: '',
      createdAt: DateTime(2026),
    );

void main() {
  test('this bill only: next month, wide range', () {
    final f = forecaster.forecast(bill(units: 100), const [])!;
    expect(f.month, '2026-10');
    expect(f.basis, ForecastBasis.thisBill);
    expect(f.units, 100);
    expect(f.unitsLow, 75);
    expect(f.unitsHigh, 125);
    expect(f.dailyBudget, 6); // 200 / 30
  });

  test('recent months: weighted toward the latest', () {
    final f = forecaster.forecast(bill(units: 100), [saved('2026-08', 150), saved('2026-07', 200)])!;
    expect(f.basis, ForecastBasis.recentMonths);
    // 0.5×100 + 0.3×150 + 0.2×200 = 135
    expect(f.units, 135);
  });

  test('same month last year, adjusted by the recent trend (summer peak)', () {
    final history = [
      HistoryEntry(month: '2025-10', units: 300), // last October (target)
      HistoryEntry(month: '2025-09', units: 200),
      HistoryEntry(month: '2025-08', units: 200),
      HistoryEntry(month: '2026-08', units: 220),
    ];
    final f = forecaster.forecast(bill(units: 220, history: history), const [])!;
    expect(f.basis, ForecastBasis.lastYear);
    // trend = (220+220)/(200+200) = 1.1 → 300 × 1.1 = 330
    expect(f.units, 330);
    expect(f.overLimit, isTrue);
  });

  test("today's meter reading projects from real daily use", () {
    final f = forecaster.forecast(
      bill(units: 106, present: 355, readingDate: '2026-09-19'),
      const [],
      meterReading: 455, // 100 units in 20 days
      today: DateTime(2026, 10, 9),
    )!;
    expect(f.basis, ForecastBasis.meterReading);
    expect(f.meterUnitsSoFar, 100);
    expect(f.meterDays, 20);
    expect(f.units, 150);
    expect(f.unitsLow, 138); // ±8% after 20 days
  });

  test('meter reading lower than the last reading is ignored', () {
    final f = forecaster.forecast(
      bill(units: 106, present: 355, readingDate: '2026-09-19'),
      const [],
      meterReading: 300,
      today: DateTime(2026, 10, 9),
    )!;
    expect(f.basis, ForecastBasis.thisBill);
  });

  test('says why a meter reading cannot be used', () {
    final b = bill(units: 106, present: 355, readingDate: '2026-09-19');
    final day = DateTime(2026, 10, 9);
    expect(forecaster.meterProblem(b, 455, today: day), isNull);
    expect(forecaster.meterProblem(b, 300, today: day), MeterProblem.belowBill);
    expect(forecaster.meterProblem(b, 360, today: DateTime(2026, 9, 19)), MeterProblem.tooSoon);
    expect(forecaster.meterProblem(b, 900, today: DateTime(2026, 11, 30)), MeterProblem.tooOld);
    expect(forecaster.meterProblem(bill(units: 106, present: 355), 400, today: day), MeterProblem.noDate);
  });

  // Boundary value analysis: 1 and 60 days are allowed; same reading is 0 units.
  test('meter reading boundaries: days 0/1, 60/61; reading below/at the bill', () {
    final b = bill(units: 106, present: 355, readingDate: '2026-09-19');
    final read = DateTime(2026, 9, 19);
    expect(forecaster.meterProblem(b, 400, today: read), MeterProblem.tooSoon); // day 0
    expect(forecaster.meterProblem(b, 400, today: read.add(const Duration(days: 1))), isNull);
    expect(forecaster.meterProblem(b, 400, today: read.add(const Duration(days: 60))), isNull);
    expect(forecaster.meterProblem(b, 400, today: read.add(const Duration(days: 61))), MeterProblem.tooOld);
    final day = DateTime(2026, 10, 9);
    expect(forecaster.meterProblem(b, 354, today: day), MeterProblem.belowBill);
    expect(forecaster.meterProblem(b, 355, today: day), isNull);
    final none = forecaster.forecast(b, const [], meterReading: 355, today: day)!;
    expect(none.units, 0);
    expect(none.amount, isNull); // nothing to scale from, not Rs 0 or a crash
  });

  test('a reading the bill did not show can be added before estimating', () {
    final b = bill(units: 106, readingDate: '2026-09-19').copyWith(presentReading: 355);
    final f = forecaster.forecast(b, const [], meterReading: 455, today: DateTime(2026, 10, 9))!;
    expect(f.basis, ForecastBasis.meterReading);
    expect(f.units, 150);
  });

  test('reading date falls back to due date minus 25 days', () {
    final f = forecaster.forecast(
      bill(units: 106, present: 355, dueDate: '2026-10-14'),
      const [],
      meterReading: 400,
      today: DateTime(2026, 10, 4), // 15 days after 19 Sep
    )!;
    expect(f.meterDays, 15);
    expect(f.units, 90); // 45 / 15 × 30
  });

  test('amount scales with the official rates and excludes arrears', () {
    // Protected, 100 units → Rs 1,054 energy; bill Rs 1,500 + Rs 500 arrears.
    final f = forecaster.forecast(bill(units: 100, total: 2000, arrears: 500, protectedConsumer: true), const [])!;
    expect(f.amount, closeTo(1500, 0.01)); // same units → same amount, without arrears
    expect(f.amountHigh! > f.amount!, isTrue);
  });

  test('crossing the limit is priced at the non-protected rate and flagged', () {
    final f = forecaster.forecast(bill(units: 190, total: 3000, protectedConsumer: true), const [])!;
    expect(f.mayCrossLimit, isTrue); // 190 ± 25% reaches past 200
    // High end (238 units) is non-protected: much more than proportional.
    expect(f.amountHigh! / f.amount!, greaterThan(238 / 190));
  });

  test('rough amounts for other unit counts, for "what if" questions', () {
    final f = forecaster.forecast(bill(units: 100, total: 2000, arrears: 500, protectedConsumer: true), const [])!;
    expect(f.amountsByUnits.keys, Forecaster.whatIfUnits);
    expect(f.amountsByUnits[100], closeTo(1500, 0.01));
    expect(f.amountsByUnits[120]! > f.amountsByUnits[100]!, isTrue);
    // Past 200 units the non-protected rate makes the bill jump.
    expect(f.amountsByUnits[210]! / f.amountsByUnits[200]!, greaterThan(1.5));
  });

  test('credit bills give no amount estimate', () {
    final f = forecaster.forecast(bill(units: 50, total: -297), const [])!;
    expect(f.amount, isNull);
    expect(f.units, 50);
    expect(f.amountsByUnits, isEmpty);
  });

  test('unknown bill month gives no forecast', () {
    expect(forecaster.forecast(bill(month: 'Sept'), const []), isNull);
  });
}
