import '../../domain/format.dart';

/// Bill data read from the photo by the backend (snake_case JSON, SDA §9.1).
class ExtractedBill {
  const ExtractedBill({
    this.disco,
    this.referenceNo,
    required this.billMonth,
    this.previousReading,
    this.presentReading,
    required this.units,
    this.tariffCategory,
    this.protectedConsumer,
    this.energyCharges,
    this.fixedCharges,
    this.fpa,
    this.qtrAdjustment,
    this.gst,
    this.incomeTax,
    this.electricityDuty,
    this.tvFee,
    this.arrears,
    required this.totalDue,
    this.lateSurcharge,
    this.dueDate,
    this.readingDate,
    this.history = const [],
    this.confidence = 1,
  });

  final String? disco;
  final String? referenceNo;
  final String billMonth; // "2026-09"
  final int? previousReading;
  final int? presentReading;
  final int units;
  final String? tariffCategory; // as printed, e.g. "A-1a(01)"

  /// The bill's printed category: true = Protected, false = Unprotected,
  /// null = not printed.
  final bool? protectedConsumer;
  final double? energyCharges; // "Cost of electricity"
  final double? fixedCharges;
  final double? fpa;
  final double? qtrAdjustment;
  final double? gst;
  final double? incomeTax;
  final double? electricityDuty;
  final double? tvFee;
  final double? arrears;
  final double totalDue; // payable within due date
  final double? lateSurcharge;
  final String? dueDate; // "2026-10-15"
  final String? readingDate; // meter read for this bill, "2026-09-19"
  final List<HistoryEntry> history; // 12-month table printed on bill
  final double confidence; // 0..1 from backend

  factory ExtractedBill.fromJson(Map<String, dynamic> json) => ExtractedBill(
        disco: _str(json['disco']),
        referenceNo: _str(json['reference_no']),
        billMonth: _str(json['bill_month']) ?? '',
        previousReading: _int(json['previous_reading']),
        presentReading: _int(json['present_reading']),
        units: _int(json['units']) ?? 0,
        tariffCategory: _str(json['tariff_category']),
        protectedConsumer: _protected(json['protected_consumer']),
        energyCharges: _double(json['energy_charges']),
        fixedCharges: _double(json['fixed_charges']),
        fpa: _double(json['fpa']),
        qtrAdjustment: _double(json['qtr_adjustment']),
        gst: _double(json['gst']),
        incomeTax: _double(json['income_tax']),
        electricityDuty: _double(json['electricity_duty']),
        tvFee: _double(json['tv_fee']),
        arrears: _double(json['arrears']),
        totalDue: _double(json['total_due']) ?? 0,
        lateSurcharge: _double(json['late_surcharge']),
        dueDate: _str(json['due_date']),
        readingDate: _str(json['reading_date']),
        history: (json['history'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
            .whereType<HistoryEntry>()
            .toList(),
        confidence: _double(json['confidence']) ?? 0,
      );

  static const maxUnits = 5000;
  static const maxAmount = 10000000.0;
  static const maxHistoryRows = 24;

  /// Parses a backend response as untrusted input (NFR-09): required fields
  /// must be present and in range, text is capped and stripped of control
  /// characters, out-of-range optional numbers are dropped.
  /// Throws [FormatException] when the bill cannot be used.
  static ExtractedBill fromUntrusted(Map<String, dynamic> json) {
    final units = _int(json['units']);
    final total = _double(json['total_due']);
    final month = _str(json['bill_month']);
    if (units == null || units < 0 || units > maxUnits) throw const FormatException('units');
    // Negative = credit bill ("CR"): nothing to pay.
    if (total == null || !total.isFinite || total.abs() > maxAmount) throw const FormatException('total_due');
    if (month == null || monthIndex(month) == null) throw const FormatException('bill_month');

    double? amount(String key) {
      final v = _double(json[key]);
      return v != null && v.isFinite && v.abs() <= maxAmount ? v : null;
    }

    int? reading(String key) {
      final v = _int(json[key]);
      return v != null && v >= 0 && v < 1000000000 ? v : null;
    }

    final dueDate = _str(json['due_date']);
    final readingDate = _str(json['reading_date']);
    final history = <HistoryEntry>[];
    for (final row in (json['history'] is List ? json['history'] as List : const [])) {
      if (row is! Map) continue;
      final h = HistoryEntry.fromJson(Map<String, dynamic>.from(row));
      if (h == null || monthIndex(h.month) == null || h.units < 0 || h.units > maxUnits) continue;
      history.add(h);
      if (history.length == maxHistoryRows) break;
    }

    return ExtractedBill(
      disco: _clean(json['disco'], 24),
      referenceNo: _clean(json['reference_no'], 40),
      billMonth: month,
      previousReading: reading('previous_reading'),
      presentReading: reading('present_reading'),
      units: units,
      tariffCategory: _clean(json['tariff_category'], 24),
      protectedConsumer: _protected(json['protected_consumer']),
      energyCharges: amount('energy_charges'),
      fixedCharges: amount('fixed_charges'),
      fpa: amount('fpa'),
      qtrAdjustment: amount('qtr_adjustment'),
      gst: amount('gst'),
      incomeTax: amount('income_tax'),
      electricityDuty: amount('electricity_duty'),
      tvFee: amount('tv_fee'),
      arrears: amount('arrears'),
      totalDue: total,
      lateSurcharge: amount('late_surcharge'),
      dueDate: dueDate != null && isIsoDate(dueDate) ? dueDate : null,
      readingDate: readingDate != null && isIsoDate(readingDate) ? readingDate : null,
      history: history,
      confidence: (_double(json['confidence']) ?? 0).clamp(0.0, 1.0),
    );
  }

  static final _controlChars = RegExp(r'[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069]');

  /// Strips control and bidi-override characters, caps length.
  static String? _clean(Object? v, int maxLength) {
    final s = _str(v)?.replaceAll(_controlChars, '').trim();
    if (s == null || s.isEmpty) return null;
    return s.length <= maxLength ? s : String.fromCharCodes(s.runes.take(maxLength));
  }

  Map<String, dynamic> toJson() => {
        'disco': disco,
        'reference_no': referenceNo,
        'bill_month': billMonth,
        'previous_reading': previousReading,
        'present_reading': presentReading,
        'units': units,
        'tariff_category': tariffCategory,
        'protected_consumer': protectedConsumer,
        'energy_charges': energyCharges,
        'fixed_charges': fixedCharges,
        'fpa': fpa,
        'qtr_adjustment': qtrAdjustment,
        'gst': gst,
        'income_tax': incomeTax,
        'electricity_duty': electricityDuty,
        'tv_fee': tvFee,
        'arrears': arrears,
        'total_due': totalDue,
        'late_surcharge': lateSurcharge,
        'due_date': dueDate,
        'reading_date': readingDate,
        'history': history.map((e) => e.toJson()).toList(),
        'confidence': confidence,
      };

  /// A credit bill: the company owes the consumer, nothing to pay.
  bool get isCredit => totalDue < 0;

  /// Used when the user corrects units or total, or types the meter reading
  /// the bill did not show.
  ExtractedBill copyWith({int? units, double? totalDue, int? presentReading}) => ExtractedBill(
        disco: disco,
        referenceNo: referenceNo,
        billMonth: billMonth,
        previousReading: previousReading,
        presentReading: presentReading ?? this.presentReading,
        units: units ?? this.units,
        tariffCategory: tariffCategory,
        protectedConsumer: protectedConsumer,
        energyCharges: energyCharges,
        fixedCharges: fixedCharges,
        fpa: fpa,
        qtrAdjustment: qtrAdjustment,
        gst: gst,
        incomeTax: incomeTax,
        electricityDuty: electricityDuty,
        tvFee: tvFee,
        arrears: arrears,
        totalDue: totalDue ?? this.totalDue,
        lateSurcharge: lateSurcharge,
        dueDate: dueDate,
        readingDate: readingDate,
        history: history,
        confidence: confidence,
      );
}

class HistoryEntry {
  const HistoryEntry({required this.month, required this.units, this.amount});

  final String month; // "2026-08"
  final int units;
  final double? amount;

  /// Returns null for rows without a usable month or units.
  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final month = _str(json['month']);
    final units = _int(json['units']);
    if (month == null || units == null) return null;
    return HistoryEntry(month: month, units: units, amount: _double(json['amount']));
  }

  Map<String, dynamic> toJson() => {'month': month, 'units': units, 'amount': amount};
}

/// true/false, or "Protected" / "Unprotected" / "Non-Protected".
bool? _protected(Object? v) {
  if (v is bool) return v;
  if (v is! String) return null;
  final s = v.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  if (s == 'PROTECTED') return true;
  if (s == 'UNPROTECTED' || s == 'NONPROTECTED') return false;
  return null;
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
  return null;
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return _double(v)?.round();
  return null;
}
