import 'package:intl/intl.dart';

import '../data/models/urdu_strings.dart';

final _number = NumberFormat('#,##0', 'en_US');

/// Western digits with thousands separators, e.g. 2,450 (NFR-02).
String formatNumber(num n) => _number.format(n.round());

final _monthPattern = RegExp(r'^(\d{4})-(\d{1,2})$');
final _datePattern = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');

/// "2026-09" → months counted from year 0, or null if not in that form.
int? monthIndex(String month) {
  final m = _monthPattern.firstMatch(month.trim());
  if (m == null) return null;
  final mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return null;
  return int.parse(m.group(1)!) * 12 + mo - 1;
}

/// Inverse of [monthIndex].
String monthKey(int index) => '${index ~/ 12}-${(index % 12 + 1).toString().padLeft(2, '0')}';

/// "2026-09" → "ستمبر 2026". Falls back to the raw text.
String formatMonth(String month, UrduStrings s) {
  final i = monthIndex(month);
  if (i == null) return month;
  return '${s.months[i % 12]} ${i ~/ 12}';
}

/// "2026-10-15" → "15 اکتوبر 2026". Falls back to the raw text.
String formatDate(String date, UrduStrings s) {
  final m = _datePattern.firstMatch(date.trim());
  if (m == null) return date;
  final mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return date;
  return '${int.parse(m.group(3)!)} ${s.months[mo - 1]} ${m.group(1)}';
}
