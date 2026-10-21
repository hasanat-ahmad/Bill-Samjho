import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/connection.dart';
import '../../domain/urdu_format.dart';

class HistoryState {
  const HistoryState({this.connection, this.bills = const [], this.chart = const []});

  final Connection? connection;

  /// Newest month first.
  final List<Bill> bills;

  /// Up to 12 months, oldest first: (month "2026-09", units).
  final List<(String, int)> chart;
}

/// S8: saved bills for one connection (FR-13, FR-16).
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._repo, this.connectionId) : super(const HistoryState()) {
    _sub = _repo.changes.listen((_) => load());
    load();
  }

  static const _chartMonths = 12;

  final BillRepository _repo;
  final String connectionId;
  late final StreamSubscription<void> _sub;

  void load() {
    final bills = _repo.billsFor(connectionId);
    emit(HistoryState(
      connection: _repo.connection(connectionId),
      bills: bills,
      chart: _chartData(bills),
    ));
  }

  /// Saved bills plus the month table printed on them; saved bills win.
  static List<(String, int)> _chartData(List<Bill> bills) {
    final byMonth = <int, int>{};
    for (final b in bills.reversed) {
      for (final h in b.data.history) {
        final i = monthIndex(h.month);
        if (i != null) byMonth[i] = h.units;
      }
    }
    for (final b in bills) {
      final i = monthIndex(b.data.billMonth);
      if (i != null) byMonth[i] = b.data.units;
    }
    final months = byMonth.keys.toList()..sort();
    return [
      for (final i in months.skip(months.length > _chartMonths ? months.length - _chartMonths : 0))
        (monthKey(i), byMonth[i]!),
    ];
  }

  Future<void> deleteBill(String id) => _repo.deleteBill(id);

  Future<void> deleteConnection() => _repo.deleteConnection(connectionId);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
