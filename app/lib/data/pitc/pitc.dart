/// Bills of the WAPDA distribution companies on PITC's official
/// duplicate-bill site. K-Electric is not on PITC.
class Disco {
  const Disco(this.code, this.slug, this.city);

  final String code; // as printed on bills, e.g. "PESCO"
  final String slug; // PITC page, e.g. "pescobill"
  final String city;

  Uri get billPage => Uri.https(PitcSite.host, '/$slug');

  static const all = [
    Disco('LESCO', 'lescobill', 'Lahore'),
    Disco('IESCO', 'iescobill', 'Islamabad'),
    Disco('FESCO', 'fescobill', 'Faisalabad'),
    Disco('GEPCO', 'gepcobill', 'Gujranwala'),
    Disco('MEPCO', 'mepcobill', 'Multan'),
    Disco('PESCO', 'pescobill', 'Peshawar'),
    Disco('HESCO', 'hescobill', 'Hyderabad'),
    Disco('SEPCO', 'sepcobill', 'Sukkur'),
    Disco('QESCO', 'qescobill', 'Quetta'),
    Disco('TESCO', 'tescobill', 'Tribal areas'),
    Disco('HAZECO', 'hazecobill', 'Hazara'),
  ];

  /// Matches "PESCO", "pesco", "Peshawar Electric Supply Company (PESCO)".
  static Disco? find(String? name) {
    if (name == null) return null;
    final upper = name.toUpperCase();
    for (final d in all) {
      if (RegExp('\\b${d.code}\\b').hasMatch(upper)) return d;
    }
    return null;
  }
}

class PitcSite {
  static const host = 'bill.pitc.com.pk';

  /// The in-app browser may only show PITC's own pages over HTTPS.
  static bool isAllowed(Uri uri) => uri.scheme == 'https' && uri.host == host;
}

/// A 14-digit reference number plus the U (urban) or R (rural) code,
/// e.g. "07 11234 1234567 U".
class ReferenceNumber {
  const ReferenceNumber(this.digits, {this.rural = false});

  final String digits; // exactly 14 digits
  final bool rural;

  /// Accepts spaces, dashes and Urdu digits; returns null unless 14 digits.
  static ReferenceNumber? parse(String raw, {bool? rural}) {
    final normalised = String.fromCharCodes(raw.trim().toUpperCase().runes.map((r) => switch (r) {
          >= 0x6F0 && <= 0x6F9 => r - 0x6F0 + 0x30, // Urdu ۰-۹
          >= 0x660 && <= 0x669 => r - 0x660 + 0x30, // Arabic ٠-٩
          _ => r,
        }));
    final digits = normalised.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 14) return null;
    return ReferenceNumber(digits, rural: rural ?? normalised.endsWith('R'));
  }

  /// Printed form: "07 11234 1234567 U".
  String get display => '${digits.substring(0, 2)} ${digits.substring(2, 7)} ${digits.substring(7)} ${rural ? 'R' : 'U'}';

  @override
  String toString() => display;
}
