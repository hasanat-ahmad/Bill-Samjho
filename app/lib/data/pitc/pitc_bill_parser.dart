import '../models/extracted_bill.dart';

/// What `assets/pitc/read_bill.js` returns from a PITC bill page.
class PitcPage {
  const PitcPage({required this.text, required this.tables});

  final String text;

  /// Tables → rows → cell text.
  final List<List<List<String>>> tables;

  factory PitcPage.fromJson(Map<String, dynamic> json) => PitcPage(
        text: json['text'] as String? ?? '',
        tables: [
          for (final t in json['tables'] as List? ?? const [])
            [
              for (final r in t as List) [for (final c in r as List) '$c'],
            ],
        ],
      );

  /// The page shows a bill (rather than the search form or an error).
  bool get looksLikeBill {
    final t = text.toUpperCase();
    return t.contains('PAYABLE WITHIN DUE DATE') || t.contains('UNITS CONSUMED');
  }
}

/// Reads a bill from PITC's duplicate-bill page by finding printed labels
/// and the value next to, below or after each one, so it does not depend on
/// exact HTML. Handles both the classic table bill and PITC's 2026 layout
/// (label on one line, Urdu label, then the value). The result still goes
/// through [ExtractedBill.fromUntrusted].
class PitcBillParser {
  /// Returns the bill, or null when units, total or bill month are missing.
  static ExtractedBill? parse(PitcPage page, {String? disco}) {
    final grid = _Grid(page.tables);
    final lines = _Lines(page.text);
    final stub = _BankStub.find(page.text);
    Object? find(List<String> labels, Object? Function(String) read) =>
        grid.find(labels, read) ?? lines.find(labels, read);

    final units = find(const ['UNITS CONSUMED'], _int) ?? find(const ['UNITS'], _int);
    final total = find(const ['PAYABLE WITHIN DUE DATE'], _amount) ?? stub?.total ?? find(const ['GRAND TOTAL'], _amount);
    final month = find(const ['BILL MONTH'], _month) ?? stub?.month;
    if (units == null || total == null || month == null) return null;

    final json = <String, dynamic>{
      'disco': disco,
      'bill_month': month,
      'units': units,
      'total_due': total,
      'reference_no': find(const ['REFERENCE NO', 'REFERENCE NUMBER', 'REF NO'], _reference) ?? stub?.reference,
      'due_date': find(const ['DUE DATE'], _date) ?? stub?.dueDate,
      'previous_reading': find(const ['PREVIOUS READING', 'PREVIOUS'], _int),
      'present_reading': find(const ['PRESENT READING', 'PRESENT'], _int),
      'tariff_category': find(const ['TARIFF'], _text),
      // Only the classic "Cost of Electricity" line is the energy charge.
      // The 2026 layout's "Total Electricity Charges" includes other items,
      // so it is deliberately not used for the energy check.
      'energy_charges': find(const ['COST OF ELECTRICITY'], _amount),
      'fixed_charges': find(const ['FIXED CHARGES', 'FIXED CHARGE'], _amount),
      'fpa': find(const ['FUEL PRICE ADJUSTMENT', 'TOTAL FPA', 'F P A', 'FPA'], _amount),
      'qtr_adjustment': find(const ['QTR TARIFF ADJ', 'QTR ADJ', 'QTR TARIFF ADJUSTMENT'], _amount),
      'gst': find(const ['GST'], _amount),
      'income_tax': find(const ['INCOME TAX'], _amount),
      'electricity_duty': find(const ['ELECTRICITY DUTY'], _amount),
      'tv_fee': find(const ['PTV FEE', 'TV FEE'], _amount),
      'arrears': find(const ['ARREAR AGE', 'ARREARS', 'ARREAR'], _amount),
      'late_surcharge': find(const ['L P SURCHARGE', 'LP SURCHARGE', 'LATE PAYMENT SURCHARGE'], _amount),
      'history': _history(page.text, month as String),
      // Read from the official page, not from a photo.
      'confidence': 1.0,
    };
    try {
      return ExtractedBill.fromUntrusted(json);
    } on FormatException {
      return null;
    }
  }

  // ---- Value readers: return null if the cell is not that kind of value ----

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  static int? _year(String y) {
    final n = int.parse(y);
    return y.length == 2 ? 2000 + n : n;
  }

  static int? _monthNumber(String name) {
    final i = _months.indexOf(name.substring(0, 3).toUpperCase());
    return i < 0 ? null : i + 1;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static Object? _int(String s) {
    final m = RegExp(r'^\s*(\d{1,9})\s*$').firstMatch(s.replaceAll(',', ''));
    return m == null ? null : int.parse(m[1]!);
  }

  /// "7,233", "Rs. 7,233", "-450.00", "297 CR" (credit → negative).
  static Object? _amount(String s) {
    final m = RegExp(r'^\s*(?:RS\.?\s*)?(-?)\s*(\d[\d,]*(?:\.\d+)?)\s*(CR)?\s*$', caseSensitive: false).firstMatch(s);
    if (m == null) return null;
    final value = double.parse(m[2]!.replaceAll(',', ''));
    return (m[1] == '-' || m[3] != null) ? -value : value;
  }

  /// "SEP 26", "Sep-26", "SEP 2026" → "2026-09".
  static Object? _month(String s) {
    final m = RegExp(r'^\s*([A-Za-z]{3})[A-Za-z]*[\s\-/]*(\d{2}|\d{4})\s*$').firstMatch(s);
    if (m == null) return null;
    final mo = _monthNumber(m[1]!);
    return mo == null ? null : '${_year(m[2]!)}-${_pad(mo)}';
  }

  /// "15 OCT 26", "15-Oct-2026" → "2026-10-15".
  static Object? _date(String s) {
    final m = RegExp(r'^\s*(\d{1,2})[\s\-/]*([A-Za-z]{3})[A-Za-z]*[\s\-/]*(\d{2}|\d{4})\s*$').firstMatch(s);
    if (m == null) return null;
    final mo = _monthNumber(m[2]!);
    final d = int.parse(m[1]!);
    if (mo == null || d < 1 || d > 31) return null;
    return '${_year(m[3]!)}-${_pad(mo)}-${_pad(d)}';
  }

  static Object? _reference(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 14 ? s.trim() : null;
  }

  /// Short Latin text such as a tariff code ("A-1A(01)"); not an Urdu label.
  static Object? _text(String s) {
    final t = s.trim();
    return t.isEmpty || t.length > 24 || !RegExp(r'[A-Za-z0-9]').hasMatch(t) ? null : t;
  }

  /// Month-wise table printed on the bill, e.g. "SEP 25 165 4210 4210".
  static List<Map<String, dynamic>> _history(String text, String billMonth) {
    final row = RegExp(
      r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-]*(\d{2})\s+(\d{1,5})\s+(-?[\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final byMonth = <String, Map<String, dynamic>>{};
    for (final m in row.allMatches(text)) {
      final key = '${_year(m[2]!)}-${_pad(_monthNumber(m[1]!)!)}';
      if (key == billMonth) continue;
      byMonth[key] = {
        'month': key,
        'units': int.parse(m[3]!),
        'amount': double.tryParse(m[4]!.replaceAll(',', '')),
      };
    }
    return byMonth.values.toList();
  }
}

/// Lines of page text, for layouts without tables: a label line (possibly
/// split over two lines), an optional Urdu label line, then the value.
class _Lines {
  _Lines(String text) : lines = [for (final l in text.split('\n')) if (l.trim().isNotEmpty) l.trim()];

  final List<String> lines;

  static bool _isUrduOnly(String s) => !RegExp(r'[A-Za-z0-9]').hasMatch(s);

  Object? find(List<String> labels, Object? Function(String) read) {
    for (final label in labels) {
      final want = _Grid._norm(label);
      for (var i = 0; i < lines.length; i++) {
        final one = _Grid._norm(lines[i]);
        final two = i + 1 < lines.length ? _Grid._norm('${lines[i]} ${lines[i + 1]}') : '';
        final int start;
        if (one == want) {
          start = i + 1;
        } else if (two == want) {
          start = i + 2;
        } else if (one.startsWith('$want ')) {
          // Label and value on one line: "DUE DATE 14 OCT 26". Values always
          // contain a digit, so "TARIFF CATEGORY" is not read as a tariff.
          final rest = lines[i].substring(lines[i].length - (one.length - want.length - 1)).trim();
          final v = RegExp(r'\d').hasMatch(rest) ? read(rest) : null;
          if (v != null) return v;
          continue;
        } else {
          continue;
        }
        for (var j = start; j < lines.length && j < start + 4; j++) {
          final v = read(lines[j]);
          if (v != null) return v;
          if (!_isUrduOnly(lines[j])) break; // reached another label
        }
      }
    }
    return null;
  }
}

/// The bank-copy line printed on PITC bills, e.g.
/// "SEP 26 - 26 11111 2222222 - 000004367 - 14 OCT 26 - 000004550 - …".
class _BankStub {
  const _BankStub(this.month, this.reference, this.total, this.dueDate);

  final Object? month;
  final String reference;
  final double total;
  final Object? dueDate;

  static _BankStub? find(String text) {
    final m = RegExp(r'\b([A-Z]{3}\s\d{2})\s-\s(\d{2}\s\d{5}\s\d{7}(?:\s?[UR])?)\s-\s(\d{6,10})\s-\s(\d{1,2}\s[A-Z]{3}\s\d{2})\b')
        .firstMatch(text);
    if (m == null) return null;
    return _BankStub(PitcBillParser._month(m[1]!), m[2]!, double.parse(m[3]!), PitcBillParser._date(m[4]!));
  }
}

/// All table cells, searchable by label.
class _Grid {
  _Grid(this.tables);

  final List<List<List<String>>> tables;

  static String _norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim();

  /// Value for the first label found: in the same cell after the label, in
  /// the cells to its right, or in the same column of the next rows.
  Object? find(List<String> labels, Object? Function(String) read) {
    for (final label in labels) {
      final want = _norm(label);
      for (final table in tables) {
        for (var r = 0; r < table.length; r++) {
          final row = table[r];
          for (var c = 0; c < row.length; c++) {
            final cell = _norm(row[c]);
            if (cell != want && !cell.startsWith('$want ')) continue;
            final value = _valueNear(table, r, c, row[c], want, read);
            if (value != null) return value;
          }
        }
      }
    }
    return null;
  }

  Object? _valueNear(List<List<String>> table, int r, int c, String raw, String label, Object? Function(String) read) {
    // Label and value in one cell: "DUE DATE 15 OCT 26".
    final words = label.split(' ').length;
    final rest = raw.trim().split(RegExp(r'\s+')).skip(words).join(' ');
    if (RegExp(r'\d').hasMatch(rest)) {
      final v = read(rest);
      if (v != null) return v;
    }
    // Value to the right in the same row.
    // Stops at the first other text, e.g. the next header in a header row.
    for (var k = c + 1; k < table[r].length && k <= c + 3; k++) {
      final cell = table[r][k];
      final v = read(cell);
      if (v != null) return v;
      if (_norm(cell).isNotEmpty) break;
    }
    // Header row with values in the next rows, same column.
    for (var k = r + 1; k < table.length && k <= r + 2; k++) {
      if (c < table[k].length) {
        final v = read(table[k][c]);
        if (v != null) return v;
      }
    }
    return null;
  }
}
