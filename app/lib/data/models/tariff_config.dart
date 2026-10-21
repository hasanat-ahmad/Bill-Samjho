/// Tariff rates and thresholds (Remote Config key `tariff_config`, SDA §10.1).
///
/// VERIFY: rates and slab method against the latest NEPRA notification.
class TariffConfig {
  const TariffConfig({
    required this.version,
    required this.sourceUrl,
    required this.protectedLimitUnits,
    required this.protectedMonths,
    required this.nearLimitUnits,
    required this.protectedSlabs,
    required this.nonProtectedSlabs,
    required this.nonProtectedFlatAboveUnits,
    required this.energyTolerancePercent,
    this.historyMonths = 6,
    this.jumpCheckRatio = 1.4,
    this.jumpWrongRatio = 2.0,
  });

  final String version;
  final String sourceUrl;
  final int protectedLimitUnits;
  final int protectedMonths;
  final int nearLimitUnits;
  final List<Slab> protectedSlabs;
  final List<Slab> nonProtectedSlabs;
  final int nonProtectedFlatAboveUnits;
  final double energyTolerancePercent;

  /// R2 big-jump thresholds. Optional in JSON, defaults per SDA §10.2.
  final int historyMonths;
  final double jumpCheckRatio;
  final double jumpWrongRatio;

  /// Throws [FormatException] if required fields are missing, so a bad
  /// remote value can be ignored in favour of the previous config.
  factory TariffConfig.fromJson(Map<String, dynamic> json) {
    final slabs = json['slabs'] as Map<String, dynamic>;
    final protectedSlabs = _slabs(slabs['protected']);
    final nonProtectedSlabs = _slabs(slabs['non_protected']);
    if (protectedSlabs.isEmpty || nonProtectedSlabs.isEmpty) {
      throw const FormatException('tariff_config has empty slabs');
    }
    return TariffConfig(
      version: json['version'] as String,
      sourceUrl: json['source_url'] as String? ?? '',
      protectedLimitUnits: (json['protected_limit_units'] as num).toInt(),
      protectedMonths: (json['protected_months'] as num).toInt(),
      nearLimitUnits: (json['near_limit_units'] as num).toInt(),
      protectedSlabs: protectedSlabs,
      nonProtectedSlabs: nonProtectedSlabs,
      nonProtectedFlatAboveUnits: (json['non_protected_flat_above_units'] as num).toInt(),
      energyTolerancePercent: (json['energy_tolerance_percent'] as num).toDouble(),
      historyMonths: (json['history_months'] as num?)?.toInt() ?? 6,
      jumpCheckRatio: (json['jump_check_ratio'] as num?)?.toDouble() ?? 1.4,
      jumpWrongRatio: (json['jump_wrong_ratio'] as num?)?.toDouble() ?? 2.0,
    );
  }

  static List<Slab> _slabs(Object? raw) => (raw as List)
      .map((e) => Slab.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList()
    ..sort((a, b) => a.from.compareTo(b.from));
}

class Slab {
  const Slab({required this.from, this.to, required this.rate});

  final int from;
  final int? to; // null = no upper limit
  final double rate; // Rs per unit

  bool contains(int units) => units >= from && (to == null || units <= to!);

  factory Slab.fromJson(Map<String, dynamic> json) => Slab(
        from: (json['from'] as num).toInt(),
        to: (json['to'] as num?)?.toInt(),
        rate: (json['rate'] as num).toDouble(),
      );
}
