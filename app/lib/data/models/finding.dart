/// Severity of a finding, ordered from least to most serious.
enum Severity { info, check, wrong }

/// The app's one-word judgement of a bill.
enum Verdict { normal, check, wrong }

class Finding {
  const Finding({required this.ruleId, required this.severity, required this.urduText});

  final String ruleId; // "summary" or "R1".."R7"
  final Severity severity;
  final String urduText; // built from template

  bool get isSummary => ruleId == summaryId;

  static const summaryId = 'summary';

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
        ruleId: json['rule_id'] as String,
        severity: Severity.values.byName(json['severity'] as String),
        urduText: json['urdu_text'] as String,
      );

  Map<String, dynamic> toJson() =>
      {'rule_id': ruleId, 'severity': severity.name, 'urdu_text': urduText};
}
