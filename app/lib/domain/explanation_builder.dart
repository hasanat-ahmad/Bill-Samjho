import '../core/i18n.dart';
import '../data/models/bill.dart';
import '../data/models/finding.dart';
import 'format.dart';

/// Turns findings into the text shown and spoken, in the current language
/// (SDA §10.4). Numbers come only from the findings' validated values.
class ExplanationBuilder {
  ExplanationBuilder(this.s);

  final AppStrings s;

  static const _templateFor = {
    'R1': 'r1_energy_mismatch',
    'R2': 'r2_jump',
    'R3': 'r3_estimated',
    'R4': 'r4_protected_lost',
    'R5': 'r5_near_limit',
    'R6': 'r6_arrears',
    'R7': 'r7_adjustments',
  };

  static const _dateParams = {'due_date'};
  static const _monthParams = {'return_month', 'month'};

  String verdictSentence(Verdict v) => s.template('verdict_${v.name}');

  String verdictLabel(Verdict v) => s.t('verdict_${v.name}_label');

  String findingText(Finding f) {
    final values = _format(f.params);
    if (f.isSummary) {
      return s.template(values.containsKey('due_date') ? 'summary' : 'summary_no_due_date', values);
    }
    var text = s.template(_templateFor[f.ruleId] ?? f.ruleId, values);
    if (f.ruleId == 'R4' && values.containsKey('return_month')) {
      text += ' ${s.template('r4_return_month', {'month': values['return_month']!})}';
    }
    return text;
  }

  /// Verdict sentence → summary → findings (wrong, check, info).
  String build(Verdict verdict, List<Finding> findings) => [
        verdictSentence(verdict),
        for (final f in ordered(findings)) findingText(f),
      ].join(' ');

  /// Summary first, then most serious first.
  static List<Finding> ordered(List<Finding> findings) => [
        ...findings.where((f) => f.isSummary),
        ...findings.where((f) => !f.isSummary).toList()
          ..sort((a, b) => b.severity.index.compareTo(a.severity.index)),
      ];

  /// Pre-filled complaint text (FR-14), using the most serious finding.
  String complaint(Bill bill, {String? referenceNo}) {
    final issues = ordered(bill.findings).where((f) => !f.isSummary);
    return s.template('complaint', {
      'ref': bill.data.referenceNo ?? referenceNo ?? '__________',
      'month': formatMonth(bill.data.billMonth, s),
      'units': formatNumber(bill.data.units),
      'finding': issues.isEmpty ? '' : findingText(issues.first),
    });
  }

  /// Text under the 200-unit meter (FR-11).
  String meterText(int units, int limit) => units <= limit
      ? s.template('meter_under', {
          'limit': formatNumber(limit),
          'units': formatNumber(units),
          'left': formatNumber(limit - units),
        })
      : s.template('meter_over', {
          'limit': formatNumber(limit),
          'units': formatNumber(units),
          'over': formatNumber(units - limit),
        });

  Map<String, String> _format(Map<String, String> params) => {
        for (final e in params.entries)
          e.key: _dateParams.contains(e.key)
              ? formatDate(e.value, s)
              : _monthParams.contains(e.key)
                  ? formatMonth(e.value, s)
                  : _number(e.value),
      };

  static String _number(String raw) {
    final n = num.tryParse(raw);
    return n == null ? raw : formatNumber(n);
  }
}
