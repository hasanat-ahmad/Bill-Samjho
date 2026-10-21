import '../data/models/bill.dart';
import '../data/models/finding.dart';
import '../data/models/urdu_strings.dart';
import 'urdu_format.dart';

/// Turns a verdict and findings into the Urdu text shown and spoken (SDA §10.4).
class ExplanationBuilder {
  ExplanationBuilder(this.strings);

  final UrduStrings strings;

  String verdictSentence(Verdict v) => strings.fill('verdict_${v.name}');

  /// Verdict sentence → summary → findings (wrong, check, info).
  String build(Verdict verdict, List<Finding> findings) {
    final summary = findings.where((f) => f.isSummary);
    final rest = findings.where((f) => !f.isSummary).toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return [
      verdictSentence(verdict),
      ...summary.map((f) => f.urduText),
      ...rest.map((f) => f.urduText),
    ].join(' ');
  }

  /// Pre-filled complaint text (FR-14), using the most serious finding.
  String complaint(Bill bill, {String? referenceNo}) {
    final issues = bill.findings.where((f) => !f.isSummary).toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
    final finding = issues.isEmpty ? '' : issues.first.urduText;
    return strings.fill('complaint', {
      'ref': bill.data.referenceNo ?? referenceNo ?? '__________',
      'month': formatMonth(bill.data.billMonth, strings),
      'units': formatNumber(bill.data.units),
      // The template already ends the sentence with "۔"
      'finding': finding.endsWith('۔') ? finding.substring(0, finding.length - 1) : finding,
    });
  }

  /// Text under the 200-unit meter (FR-11).
  String meterText(int units, int limit) => units <= limit
      ? strings.fill('meter_under', {
          'limit': formatNumber(limit),
          'units': formatNumber(units),
          'left': formatNumber(limit - units),
        })
      : strings.fill('meter_over', {
          'limit': formatNumber(limit),
          'units': formatNumber(units),
          'over': formatNumber(units - limit),
        });
}
