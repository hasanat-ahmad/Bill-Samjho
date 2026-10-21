import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/bill_repository.dart';
import '../../data/models/bill.dart';
import '../../data/models/connection.dart';

class ResultState {
  const ResultState({this.bill, this.connection, this.loaded = false});

  final Bill? bill;
  final Connection? connection;
  final bool loaded;
}

class ResultCubit extends Cubit<ResultState> {
  ResultCubit(this._repo) : super(const ResultState());

  final BillRepository _repo;

  void load(String billId) {
    final bill = _repo.bill(billId);
    emit(ResultState(
      bill: bill,
      connection: bill == null ? null : _repo.connection(bill.connectionId),
      loaded: true,
    ));
  }
}
