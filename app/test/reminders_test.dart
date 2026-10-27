import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/core/i18n.dart';
import 'package:bill_samjho/data/models/bill.dart';
import 'package:bill_samjho/data/models/connection.dart';
import 'package:bill_samjho/data/models/extracted_bill.dart';
import 'package:bill_samjho/data/models/finding.dart';
import 'package:bill_samjho/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final en = AppStrings(AppLanguage.en, _json('assets/i18n/en.json'));
  final ur = AppStrings(AppLanguage.ur, _json('assets/i18n/ur.json'));
  const planner = ReminderPlanner();

  Connection meter(String id, {String? ref = '15 26821 0000000', String? disco = 'PESCO'}) =>
      Connection(id: id, nickname: 'Home', disco: disco, referenceNo: ref, createdAt: DateTime(2026));
  Bill bill(String id, {String? due = '2026-10-14', double total = 4367}) => Bill(
        id: id,
        connectionId: 'c',
        data: ExtractedBill(billMonth: '2026-09', units: 106, totalDue: total, dueDate: due),
        verdict: Verdict.normal,
        findings: const [],
        imagePath: '',
        createdAt: DateTime(2026),
      );

  test('due reminder 3 days before, new-bill reminder 20 days after the due date', () {
    final plan = planner.plan(connections: [meter('c')], latestBill: (_) => bill('b'), s: en, now: DateTime(2026, 10, 1));
    expect(plan, hasLength(2));
    expect(plan[0].at, DateTime(2026, 10, 11, 10));
    expect(plan[0].title, 'Home: bill due 14 October 2026');
    expect(plan[0].body, contains('Rs 4,367'));
    expect(plan[0].route, '/result/b');
    expect(plan[1].at, DateTime(2026, 11, 3, 10));
    expect(plan[1].route, '/lookup/c?latest=1');
  });

  test('saved late: the reminder moves to the day before; after the due date only the new bill', () {
    final late = planner.plan(connections: [meter('c')], latestBill: (_) => bill('b'), s: en, now: DateTime(2026, 10, 12));
    expect(late.first.at, DateTime(2026, 10, 13, 10));
    final past = planner.plan(connections: [meter('c')], latestBill: (_) => bill('b'), s: en, now: DateTime(2026, 10, 15));
    expect(past.map((r) => r.route), ['/lookup/c?latest=1']);
  });

  test('no reminder to pay a credit; no PITC reminder without a reference number', () {
    final plan = planner.plan(
      connections: [meter('c', ref: null)],
      latestBill: (_) => bill('b', total: -297),
      s: en,
      now: DateTime(2026, 10, 1),
    );
    expect(plan, isEmpty);
  });

  test('no due date, no reminders', () {
    expect(planner.plan(connections: [meter('c')], latestBill: (_) => bill('b', due: null), s: en, now: DateTime(2026, 10, 1)), isEmpty);
  });

  test('ids are stable per meter and differ between meters and kinds', () {
    expect(ReminderPlanner.idFor('a', 0), ReminderPlanner.idFor('a', 0));
    expect(ReminderPlanner.idFor('a', 0), isNot(ReminderPlanner.idFor('a', 1)));
    expect(ReminderPlanner.idFor('a', 0), isNot(ReminderPlanner.idFor('b', 0)));
    expect(ReminderPlanner.idFor('x' * 200, 1), lessThan(1 << 31));
  });

  test('reminders are written in the app language', () {
    final plan = planner.plan(connections: [meter('c')], latestBill: (_) => bill('b'), s: ur, now: DateTime(2026, 10, 1));
    expect(plan[0].title, contains('آخری تاریخ'));
    expect(plan[0].body, contains('4,367 روپے'));
  });

  // QA D-01: one bill with a date DateTime.parse cannot read must not stop
  // the reminders of every other meter.
  test('a bill with an unreadable due date is skipped, others still planned', () {
    final plan = planner.plan(
      connections: [meter('a'), meter('c')],
      latestBill: (id) => id == 'a' ? bill('bad', due: '2026-10-5') : bill('b'),
      s: en,
      now: DateTime(2026, 10, 1),
    );
    expect(plan.map((r) => r.route), ['/result/b', '/lookup/c?latest=1']);
  });
}
