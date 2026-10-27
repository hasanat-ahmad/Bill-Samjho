import 'package:bill_samjho/domain/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boundary value analysis for dates read from bills (QA D-01).
void main() {
  test('real calendar dates only, at each edge of month and year', () {
    expect(isoDate('2026-01-01'), '2026-01-01');
    expect(isoDate('2026-12-31'), '2026-12-31');
    expect(isoDate('2026-02-28'), '2026-02-28');
    expect(isoDate('2026-02-29'), isNull); // 2026 is not a leap year
    expect(isoDate('2028-02-29'), '2028-02-29');
    expect(isoDate('2026-04-30'), '2026-04-30');
    expect(isoDate('2026-04-31'), isNull);
    expect(isoDate('2026-00-10'), isNull);
    expect(isoDate('2026-13-01'), isNull);
    expect(isoDate('2026-01-00'), isNull);
    expect(isoDate('2026-01-32'), isNull);
  });

  test('one-digit month or day is written out; isIsoDate accepts only what DateTime.parse reads', () {
    expect(isoDate(' 2026-10-5 '), '2026-10-05');
    expect(isoDate('2026-1-5'), '2026-01-05');
    expect(isIsoDate('2026-10-5'), isFalse);
    expect(isIsoDate('2026-10-05'), isTrue);
    for (final d in ['2026-10-05', '2028-02-29']) {
      expect(DateTime.parse(d).day, int.parse(d.substring(8)));
    }
  });

  test('months: 1 to 12 only', () {
    expect(monthIndex('2026-00'), isNull);
    expect(monthKey(monthIndex('2026-1')!), '2026-01');
    expect(monthKey(monthIndex('2026-12')!), '2026-12');
    expect(monthIndex('2026-13'), isNull);
  });
}
