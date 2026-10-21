import 'dart:math' as math;

import '../data/models/bill.dart';
import '../data/models/extracted_bill.dart';
import '../data/models/finding.dart';
import '../data/models/tariff_config.dart';
import '../data/models/urdu_strings.dart';
import 'urdu_format.dart';

class RulesResult {
  const RulesResult(this.verdict, this.findings);

  final Verdict verdict;

  /// Summary first, then findings ordered wrong → check → info.
  final List<Finding> findings;
}

/// Judges a bill (SDA §10). Pure Dart: every number in the output comes from
/// the validated bill data or the tariff config, filled into fixed templates.
class RulesEngine {
  RulesEngine(this.config, this.strings);

  final TariffConfig config;
  final UrduStrings strings;

  RulesResult evaluate(ExtractedBill current, List<Bill> pastBillsForConnection) {
    final past = _pastUnitsByMonth(current, pastBillsForConnection);
    final currentIndex = monthIndex(current.billMonth);

    final findings = <Finding>[
      ?_energyCheck(current),
      ?_bigJump(current, past, currentIndex),
      ?_sameReading(current, past, currentIndex),
      ?_protectedLost(current, past, currentIndex),
      ?_nearLimit(current),
      ?_arrears(current),
      ?_adjustments(current),
    ];
    // Stable sort keeps rule order within the same severity.
    final ordered = _stableSortBySeverity(findings);

    final worst = findings.fold<Severity?>(
      null,
      (w, f) => w == null || f.severity.index > w.index ? f.severity : w,
    );
    final verdict = switch (worst) {
      Severity.wrong => Verdict.wrong,
      Severity.check => Verdict.check,
      _ => Verdict.normal,
    };

    return RulesResult(verdict, [_summary(current), ...ordered]);
  }

  /// Energy charge in rupees for [units], or null when the tariff does not
  /// apply (protected rates above the protected limit).
  double? computeEnergy(int units, {required bool protected}) {
    if (units <= 0) return 0;
    if (protected) {
      if (units > config.protectedLimitUnits) return null;
      return _incremental(units, config.protectedSlabs);
    }
    if (units > config.nonProtectedFlatAboveUnits) {
      // VERIFY: all units at the rate of the slab the total falls in.
      final slab = config.nonProtectedSlabs.lastWhere(
        (s) => s.contains(units),
        orElse: () => config.nonProtectedSlabs.last,
      );
      return _round2(units * slab.rate);
    }
    return _incremental(units, config.nonProtectedSlabs);
  }

  double _incremental(int units, List<Slab> slabs) {
    var total = 0.0;
    for (final s in slabs) {
      final upper = math.min(units, s.to ?? units);
      final inSlab = upper - (s.from - 1);
      if (inSlab > 0) total += inSlab * s.rate;
    }
    return _round2(total);
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  // ---- History ----

  /// Units by month index for months before the current bill.
  /// Saved bills (possibly user-corrected) override the printed history table.
  Map<int, int> _pastUnitsByMonth(ExtractedBill current, List<Bill> pastBills) {
    final currentIndex = monthIndex(current.billMonth);
    final result = <int, int>{};
    if (currentIndex == null) return result;
    void add(String month, int units) {
      final i = monthIndex(month);
      if (i != null && i < currentIndex) result[i] = units;
    }

    for (final h in current.history) {
      add(h.month, h.units);
    }
    for (final b in pastBills) {
      add(b.data.billMonth, b.data.units);
    }
    return result;
  }

  /// Units for the [count] calendar months just before [currentIndex].
  Map<int, int> _window(Map<int, int> past, int currentIndex, int count) => {
        for (final e in past.entries)
          if (e.key >= currentIndex - count) e.key: e.value,
      };

  // ---- Rules (SDA §10.2) ----

  Finding _summary(ExtractedBill b) {
    final values = {
      'units': formatNumber(b.units),
      'total': formatNumber(b.totalDue),
      if (b.dueDate != null) 'due_date': formatDate(b.dueDate!, strings),
    };
    return Finding(
      ruleId: Finding.summaryId,
      severity: Severity.info,
      urduText: strings.fill(b.dueDate == null ? 'summary_no_due_date' : 'summary', values),
    );
  }

  /// R1: printed energy charge does not match either tariff.
  Finding? _energyCheck(ExtractedBill b) {
    final printed = b.energyCharges;
    if (printed == null || b.units <= 0) return null;
    final candidates = [
      computeEnergy(b.units, protected: true),
      computeEnergy(b.units, protected: false),
    ].whereType<double>().where((c) => c > 0).toList();
    if (candidates.isEmpty) return null;

    double diffPercent(double c) => (c - printed).abs() / c * 100;
    if (candidates.any((c) => diffPercent(c) <= config.energyTolerancePercent)) return null;

    final expected = candidates.reduce((a, c) => diffPercent(c) < diffPercent(a) ? c : a);
    return Finding(
      ruleId: 'R1',
      severity: Severity.wrong,
      urduText: strings.fill('r1_energy_mismatch', {
        'expected': formatNumber(expected),
        'printed': formatNumber(printed),
      }),
    );
  }

  /// R2: units much higher than the recent average.
  Finding? _bigJump(ExtractedBill b, Map<int, int> past, int? currentIndex) {
    if (currentIndex == null) return null;
    final window = _window(past, currentIndex, config.historyMonths);
    if (window.isEmpty) return null;
    final avg = window.values.reduce((a, c) => a + c) / window.length;
    if (avg <= 0 || b.units <= avg * config.jumpCheckRatio) return null;
    return Finding(
      ruleId: 'R2',
      severity: b.units > avg * config.jumpWrongRatio ? Severity.wrong : Severity.check,
      urduText: strings.fill('r2_jump', {'avg': formatNumber(avg)}),
    );
  }

  /// R3: reading looks estimated.
  Finding? _sameReading(ExtractedBill b, Map<int, int> past, int? currentIndex) {
    if (b.units <= 0) return null;
    final sameAsLastMonth = currentIndex != null && past[currentIndex - 1] == b.units;
    final meterNotMoved = b.presentReading != null &&
        b.previousReading != null &&
        b.presentReading == b.previousReading;
    if (!sameAsLastMonth && !meterNotMoved) return null;
    return Finding(ruleId: 'R3', severity: Severity.check, urduText: strings.fill('r3_estimated'));
  }

  /// R4: protected status lost this month or in the last N months.
  Finding? _protectedLost(ExtractedBill b, Map<int, int> past, int? currentIndex) {
    final limit = config.protectedLimitUnits;
    int? lastOver; // month index of the latest month over the limit
    if (currentIndex != null) {
      for (final e in _window(past, currentIndex, config.protectedMonths).entries) {
        if (e.value > limit && (lastOver == null || e.key > lastOver)) lastOver = e.key;
      }
    }
    final overNow = b.units > limit;
    if (!overNow && lastOver == null) return null;
    if (overNow && currentIndex != null) lastOver = currentIndex;

    var text = strings.fill('r4_protected_lost', {
      'limit': formatNumber(limit),
      'months': formatNumber(config.protectedMonths),
    });
    if (lastOver != null) {
      final returnMonth = monthKey(lastOver + config.protectedMonths);
      text += ' ${strings.fill('r4_return_month', {'month': formatMonth(returnMonth, strings)})}';
    }
    return Finding(ruleId: 'R4', severity: Severity.check, urduText: text);
  }

  /// R5: close to the protected limit.
  Finding? _nearLimit(ExtractedBill b) {
    final limit = config.protectedLimitUnits;
    if (b.units < config.nearLimitUnits || b.units > limit) return null;
    return Finding(
      ruleId: 'R5',
      severity: Severity.info,
      urduText: strings.fill('r5_near_limit', {
        'limit': formatNumber(limit),
        'left': formatNumber(limit - b.units),
      }),
    );
  }

  /// R6: arrears included.
  Finding? _arrears(ExtractedBill b) {
    final arrears = b.arrears;
    if (arrears == null || arrears <= 0) return null;
    return Finding(
      ruleId: 'R6',
      severity: Severity.check,
      urduText: strings.fill('r6_arrears', {'arrears': formatNumber(arrears)}),
    );
  }

  /// R7: FPA or quarterly adjustment charged.
  Finding? _adjustments(ExtractedBill b) {
    if ((b.fpa ?? 0) <= 0 && (b.qtrAdjustment ?? 0) <= 0) return null;
    return Finding(ruleId: 'R7', severity: Severity.info, urduText: strings.fill('r7_adjustments'));
  }

  static List<Finding> _stableSortBySeverity(List<Finding> findings) {
    final indexed = findings.indexed.toList()
      ..sort((a, b) {
        final bySeverity = b.$2.severity.index.compareTo(a.$2.severity.index);
        return bySeverity != 0 ? bySeverity : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }
}
