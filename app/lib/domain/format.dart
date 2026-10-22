import 'package:intl/intl.dart';

import '../core/i18n.dart';

final _number = NumberFormat('#,##0', 'en_US');

/// Western digits with thousands separators in both languages, e.g. 2,450 (NFR-02).
String formatNumber(num n) => _number.format(n.round());

/// "Rs 2,450" / "2,450 روپے".
String formatAmount(num n, AppStrings s) => s.t('amount', {'amount': formatNumber(n)});

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

/// True for a real calendar date in "YYYY-MM-DD" form.
bool isIsoDate(String date) {
  final m = _datePattern.firstMatch(date.trim());
  if (m == null) return false;
  final mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  return mo >= 1 && mo <= 12 && d >= 1 && d <= 31;
}

/// "2026-09" → "September 2026" / "ستمبر 2026". Falls back to the raw text.
String formatMonth(String month, AppStrings s) {
  final i = monthIndex(month);
  if (i == null) return month;
  return '${s.months[i % 12]} ${i ~/ 12}';
}

/// "2026-09" → "September" / "ستمبر" (chart labels).
String formatMonthName(String month, AppStrings s) {
  final i = monthIndex(month);
  return i == null ? '' : s.months[i % 12];
}

/// "2026-10-15" → "15 October 2026" / "15 اکتوبر 2026". Falls back to the raw text.
String formatDate(String date, AppStrings s) {
  if (!isIsoDate(date)) return date;
  final m = _datePattern.firstMatch(date.trim())!;
  return '${int.parse(m.group(3)!)} ${s.months[int.parse(m.group(2)!) - 1]} ${m.group(1)}';
}
