import 'dart:math' as math;

import '../data/models/bill.dart';
import '../data/models/extracted_bill.dart';
import '../data/models/tariff_config.dart';
import 'format.dart';
import 'rules_engine.dart';

/// What the next-bill estimate is based on, most reliable first.
enum ForecastBasis { meterReading, lastYear, recentMonths, thisBill }

/// Why today's meter reading cannot be used for an estimate.
enum MeterProblem {
  /// Lower than the reading printed on the bill.
  belowBill,

  /// Taken the same day as the bill's reading.
  tooSoon,

  /// More than two months after the bill's reading: add a newer bill.
  tooOld,

  /// The bill shows no reading date or due date to count days from.
  noDate,
}

class BillForecast {
  const BillForecast({
    required this.month,
    required this.units,
    required this.unitsLow,
    required this.unitsHigh,
    required this.basis,
    required this.limit,
    required this.dailyBudget,
    this.amount,
    this.amountLow,
    this.amountHigh,
    this.meterUnitsSoFar,
    this.meterDays,
    this.amountsByUnits = const {},
  });

  /// Bill month being estimated, "2026-10".
  final String month;
  final int units, unitsLow, unitsHigh;

  /// Rough total in rupees; null when it cannot be estimated (e.g. credit bill).
  final double? amount, amountLow, amountHigh;

  final ForecastBasis basis;
  final int limit;

  /// Units per day that keep the month at or under [limit].
  final int dailyBudget;

  /// Set when [basis] is [ForecastBasis.meterReading].
  final int? meterUnitsSoFar, meterDays;

  /// Rough total for other unit counts ([Forecaster.whatIfUnits]), so the
  /// helper can answer "what if I use 150 units?".
  final Map<int, double> amountsByUnits;

  /// Likely over the protected limit.
  bool get overLimit => units > limit;

  /// The range reaches past the limit even though the estimate does not.
  bool get mayCrossLimit => !overLimit && unitsHigh > limit;
}

/// Estimates the next bill from the bill history (pure Dart, no AI): the same
/// month last year adjusted by the recent trend, else recent months, else
/// this bill. With today's meter reading it projects from actual daily use.
class Forecaster {
  Forecaster(this.config) : _engine = RulesEngine(config);

  final TariffConfig config;
  final RulesEngine _engine;

  static const daysPerBill = 30;

  /// Today's date; tests replace it.
  static DateTime Function() now = DateTime.now;

  /// Unit counts for [BillForecast.amountsByUnits].
  static final whatIfUnits = List<int>.unmodifiable([for (var u = 10; u <= 300; u += 10) u, 350, 400, 500]);

  BillForecast? forecast(ExtractedBill bill, List<Bill> past, {int? meterReading, DateTime? today}) {
    final current = monthIndex(bill.billMonth);
    if (current == null) return null;
    final byMonth = _unitsByMonth(bill, past, current);
    final limit = config.protectedLimitUnits;

    double estimate;
    double spread;
    ForecastBasis basis;
    int? soFar, days;

    final meter = _fromMeter(bill, meterReading, today);
    if (meter != null) {
      (estimate, spread, soFar, days) = meter;
      basis = ForecastBasis.meterReading;
    } else if (byMonth[current + 1 - 12] case final lastYear?) {
      estimate = lastYear * _trend(byMonth, current);
      spread = 0.15;
      basis = ForecastBasis.lastYear;
    } else if (byMonth.containsKey(current - 1)) {
      // Weighted toward the latest months.
      const weights = [0.5, 0.3, 0.2];
      var sum = 0.0, weight = 0.0;
      for (var i = 0; i < 3; i++) {
        final u = byMonth[current - i];
        if (u == null) continue;
        sum += u * weights[i];
        weight += weights[i];
      }
      estimate = sum / weight;
      spread = 0.2;
      basis = ForecastBasis.recentMonths;
    } else {
      estimate = bill.units.toDouble();
      spread = 0.25;
      basis = ForecastBasis.thisBill;
    }

    final units = estimate.round();
    final low = (estimate * (1 - spread)).floor();
    final high = (estimate * (1 + spread)).ceil();
    final amounts = [for (final u in [units, low, high]) _amount(bill, byMonth, current, u)];
    final whatIf = {
      for (final u in whatIfUnits) u: ?_amount(bill, byMonth, current, u),
    };

    return BillForecast(
      month: monthKey(current + 1),
      units: units,
      unitsLow: math.max(0, low),
      unitsHigh: high,
      amount: amounts[0],
      amountLow: amounts[1],
      amountHigh: amounts[2],
      basis: basis,
      limit: limit,
      dailyBudget: limit ~/ daysPerBill,
      meterUnitsSoFar: soFar,
      meterDays: days,
      amountsByUnits: whatIf,
    );
  }

  Map<int, int> _unitsByMonth(ExtractedBill bill, List<Bill> past, int current) {
    final result = <int, int>{};
    for (final h in bill.history) {
      final i = monthIndex(h.month);
      if (i != null && i < current) result[i] = h.units;
    }
    for (final b in past) {
      final i = monthIndex(b.data.billMonth);
      if (i != null && i < current) result[i] = b.data.units;
    }
    result[current] = bill.units;
    return result;
  }

  /// Recent use compared with the same months last year, within limits so
  /// one odd month does not swing the estimate.
  double _trend(Map<int, int> byMonth, int current) {
    var now = 0, then = 0, pairs = 0;
    for (var i = 0; i < 3; i++) {
      final a = byMonth[current - i], b = byMonth[current - i - 12];
      if (a == null || b == null || b == 0) continue;
      now += a;
      then += b;
      pairs++;
    }
    if (pairs < 2) return 1;
    return (now / then).clamp(0.7, 1.4);
  }

  static const maxMeterDays = 60;

  /// Why [reading] cannot give an estimate from this bill, or null if it can.
  /// Needs the bill's [ExtractedBill.presentReading].
  MeterProblem? meterProblem(ExtractedBill bill, int reading, {DateTime? today}) {
    final present = bill.presentReading;
    if (present != null && reading < present) return MeterProblem.belowBill;
    final readOn = _readingDate(bill);
    if (readOn == null) return MeterProblem.noDate;
    final days = (today ?? now()).difference(readOn).inDays;
    if (days < 1) return MeterProblem.tooSoon;
    if (days > maxMeterDays) return MeterProblem.tooOld;
    return null;
  }

  /// (estimate, spread, units so far, days) from today's meter reading.
  (double, double, int, int)? _fromMeter(ExtractedBill bill, int? reading, DateTime? today) {
    final present = bill.presentReading;
    if (reading == null || present == null || meterProblem(bill, reading, today: today) != null) return null;
    final days = (today ?? now()).difference(_readingDate(bill)!).inDays;
    final soFar = reading - present;
    final estimate = soFar / days * daysPerBill;
    // The more of the month has passed, the surer the projection.
    final spread = days >= 20 ? 0.08 : days >= 10 ? 0.15 : 0.25;
    return (estimate, spread, soFar, days);
  }

  /// The bill's meter reading date, or about 25 days before the due date.
  static DateTime? _readingDate(ExtractedBill bill) {
    final raw = bill.readingDate ?? bill.dueDate;
    if (raw == null || !isIsoDate(raw)) return null;
    final date = DateTime.parse(raw);
    return bill.readingDate != null ? date : date.subtract(const Duration(days: 25));
  }

  /// Rough total for [units]: the official energy cost, scaled by this
  /// bill's ratio of total (without arrears) to energy cost, so taxes and
  /// fixed charges are carried over approximately.
  double? _amount(ExtractedBill bill, Map<int, int> byMonth, int current, int units) {
    if (bill.units <= 0 || units <= 0) return null;
    final base = bill.totalDue - (bill.arrears ?? 0);
    if (base <= 0) return null;
    final nowTariff = _tariffNow(bill, byMonth, current);
    final energyNow = _engine.computeEnergy(bill.units, nowTariff);
    // Going over the limit means paying the non-protected rate.
    final nextTariff = units > config.protectedLimitUnits ? Tariff.nonProtected : nowTariff;
    final energyNext = _engine.computeEnergy(units, nextTariff);
    if (energyNow == null || energyNext == null || energyNow <= 0) return null;
    return base * energyNext / energyNow;
  }

  Tariff _tariffNow(ExtractedBill bill, Map<int, int> byMonth, int current) {
    if (bill.protectedConsumer != null) return bill.protectedConsumer! ? Tariff.protected : Tariff.nonProtected;
    final limit = config.protectedLimitUnits;
    final lastSix = [for (var i = 0; i <= config.protectedMonths; i++) ?byMonth[current - i]];
    return lastSix.every((u) => u <= limit) ? Tariff.protected : Tariff.nonProtected;
  }
}
