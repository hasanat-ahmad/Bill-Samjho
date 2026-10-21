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
        history: (json['history'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
            .whereType<HistoryEntry>()
            .toList(),
        confidence: _double(json['confidence']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'disco': disco,
        'reference_no': referenceNo,
        'bill_month': billMonth,
        'previous_reading': previousReading,
        'present_reading': presentReading,
        'units': units,
        'tariff_category': tariffCategory,
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
        'history': history.map((e) => e.toJson()).toList(),
        'confidence': confidence,
      };

  /// Used by the confirm screen when the user corrects units or total.
  ExtractedBill copyWith({int? units, double? totalDue}) => ExtractedBill(
        disco: disco,
        referenceNo: referenceNo,
        billMonth: billMonth,
        previousReading: previousReading,
        presentReading: presentReading,
        units: units ?? this.units,
        tariffCategory: tariffCategory,
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
