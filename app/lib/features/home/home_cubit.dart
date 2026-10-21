import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/connection.dart';

class ConnectionSummary {
  const ConnectionSummary(this.connection, this.latestBill);

  final Connection connection;
  final Bill? latestBill;
}

/// Connection cards on Home; reloads whenever bills or connections change.
class HomeCubit extends Cubit<List<ConnectionSummary>> {
  HomeCubit(this._repo) : super(const []) {
    _sub = _repo.changes.listen((_) => load());
    load();
  }

  final BillRepository _repo;
  late final StreamSubscription<void> _sub;

  void load() => emit([
        for (final c in _repo.connections()) ConnectionSummary(c, _repo.latestBill(c.id)),
      ]);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
