import 'extracted_bill.dart';
import 'finding.dart';

/// A scanned and analysed bill, saved under its connection.
class Bill {
  const Bill({
    required this.id,
    required this.connectionId,
    required this.data,
    required this.verdict,
    required this.findings,
    required this.imagePath,
    required this.createdAt,
  });

  final String id;
  final String connectionId;
  final ExtractedBill data;
  final Verdict verdict;
  final List<Finding> findings;
  final String imagePath; // local compressed copy
  final DateTime createdAt;

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String,
        connectionId: json['connection_id'] as String,
        data: ExtractedBill.fromJson(Map<String, dynamic>.from(json['data'] as Map)),
        verdict: Verdict.values.byName(json['verdict'] as String),
        findings: (json['findings'] as List)
            .map((e) => Finding.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        imagePath: json['image_path'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'connection_id': connectionId,
        'data': data.toJson(),
        'verdict': verdict.name,
        'findings': findings.map((e) => e.toJson()).toList(),
        'image_path': imagePath,
        'created_at': createdAt.toIso8601String(),
      };
}
