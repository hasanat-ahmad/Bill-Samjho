/// Severity of a finding, ordered from least to most serious.
enum Severity { info, check, wrong }

/// The app's one-word judgement of a bill.
enum Verdict { normal, check, wrong }

/// One result of the rules engine. Holds data, not text, so a saved bill is
/// explained in whichever language the user picks later.
class Finding {
  const Finding({required this.ruleId, required this.severity, this.params = const {}});

  final String ruleId; // "summary" or "R1".."R7"
  final Severity severity;

  /// Raw values for the template: numbers ("5867"), months ("2026-09"),
  /// dates ("2026-10-15").
  final Map<String, String> params;

  bool get isSummary => ruleId == summaryId;

  static const summaryId = 'summary';

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
        ruleId: json['rule_id'] as String,
        severity: Severity.values.byName(json['severity'] as String),
        params: Map<String, String>.from(json['params'] as Map? ?? const {}),
      );

  Map<String, dynamic> toJson() => {'rule_id': ruleId, 'severity': severity.name, 'params': params};
}
