import '../core/i18n.dart';
import '../data/models/bill.dart';
import '../data/models/connection.dart';
import '../data/pitc/pitc.dart';
import 'format.dart';

/// A notification to show at [at]: tapping it opens [route].
class PlannedReminder {
  const PlannedReminder({required this.id, required this.at, required this.title, required this.body, required this.route});

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String route;

  @override
  String toString() => 'PlannedReminder($id, $at, $route)';
}

/// Works out each meter's reminders from its latest bill (pure Dart):
/// - the due date, [dueDaysBefore] days ahead (or the day before, when the
///   bill was saved late), so the late fee is avoided;
/// - the next bill, [nextBillDaysAfterDue] days after this one's due date,
///   for meters whose bill can be opened on PITC by reference number.
/// Both at [hour] o'clock, in the phone's time.
class ReminderPlanner {
  const ReminderPlanner();

  static const dueDaysBefore = 3;
  static const nextBillDaysAfterDue = 20;
  static const hour = 10;

  List<PlannedReminder> plan({
    required List<Connection> connections,
    required Bill? Function(String connectionId) latestBill,
    required AppStrings s,
    required DateTime now,
  }) {
    final out = <PlannedReminder>[];
    for (final c in connections) {
      final bill = latestBill(c.id);
      final due = bill?.data.dueDate;
      if (bill == null || due == null || !isIsoDate(due)) continue;
      final dueDay = DateTime.parse(due);
      DateTime at(int days) => DateTime(dueDay.year, dueDay.month, dueDay.day + days, hour);

      if (!bill.data.isCredit) {
        final when = [at(-dueDaysBefore), at(-1)].where((d) => d.isAfter(now)).firstOrNull;
        if (when != null) {
          out.add(PlannedReminder(
            id: idFor(c.id, 0),
            at: when,
            title: s.t('notif_due_title', {'name': c.nickname, 'date': formatDate(due, s)}),
            body: s.t('notif_due_body', {'amount': formatNumber(bill.data.totalDue.round())}),
            route: '/result/${bill.id}',
          ));
        }
      }

      final next = at(nextBillDaysAfterDue);
      if (c.referenceNo != null && Disco.find(c.disco) != null && next.isAfter(now)) {
        out.add(PlannedReminder(
          id: idFor(c.id, 1),
          at: next,
          title: s.t('notif_new_title', {'name': c.nickname}),
          body: s.t('notif_new_body'),
          route: '/lookup/${c.id}?latest=1',
        ));
      }
    }
    return out;
  }

  /// Stable per meter and kind, inside Android's 32-bit notification ids.
  static int idFor(String connectionId, int kind) {
    var h = 0;
    for (final c in connectionId.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return (h % 100000000) * 2 + kind;
  }
}
