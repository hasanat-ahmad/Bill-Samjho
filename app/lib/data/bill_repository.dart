import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../domain/rules_engine.dart';
import 'api_service.dart';
import 'local_store.dart';
import 'models/bill.dart';
import 'models/connection.dart';
import 'models/extracted_bill.dart';
import 'models/tariff_config.dart';
import 'models/urdu_strings.dart';

/// Single entry point for connections and bills.
class BillRepository {
  BillRepository({
    required LocalStore store,
    required ApiService api,
    required TariffConfig Function() tariffConfig,
    required UrduStrings strings,
    required Directory imagesDir,
  })  : _store = store,
        _api = api,
        _tariffConfig = tariffConfig,
        _strings = strings,
        _imagesDir = imagesDir;

  final LocalStore _store;
  final ApiService _api;
  final TariffConfig Function() _tariffConfig;
  final UrduStrings _strings;
  final Directory _imagesDir;
  final _changes = StreamController<void>.broadcast();
  static const _uuid = Uuid();

  TariffConfig get tariffConfig => _tariffConfig();

  /// Fires after any connection or bill is added or deleted.
  Stream<void> get changes => _changes.stream;

  /// Random ID made on first launch; used only for backend rate limiting.
  String get deviceId {
    var id = _store.setting<String>(SettingKeys.deviceId);
    if (id == null) {
      id = _uuid.v4();
      _store.setSetting(SettingKeys.deviceId, id);
    }
    return id;
  }

  // ---- Connections ----

  List<Connection> connections() => _store.connections();

  Connection? connection(String id) => _store.connection(id);

  Future<Connection> addConnection(String nickname) async {
    final c = Connection(id: _uuid.v4(), nickname: nickname.trim(), createdAt: DateTime.now());
    await _store.saveConnection(c);
    _changes.add(null);
    return c;
  }

  Future<void> deleteConnection(String id) async {
    for (final b in _store.billsFor(id)) {
      await deleteBill(b.id);
    }
    await _store.deleteConnection(id);
    _changes.add(null);
  }

  // ---- Bills ----

  /// Newest month first.
  List<Bill> billsFor(String connectionId) => _store.billsFor(connectionId);

  Bill? latestBill(String connectionId) {
    final bills = billsFor(connectionId);
    return bills.isEmpty ? null : bills.first;
  }

  Bill? bill(String id) => _store.bill(id);

  /// Throws [ApiException].
  Future<ExtractedBill> extract(Uint8List jpeg) => _api.extractBill(jpeg, deviceId);

  /// Runs the rules engine on the (possibly user-corrected) [data], then saves
  /// the bill and its image. A rescan of the same month replaces the old bill.
  Future<Bill> analyseAndSave({
    required String connectionId,
    required ExtractedBill data,
    required Uint8List jpeg,
  }) async {
    final existing = billsFor(connectionId);
    for (final old in existing.where((b) => b.data.billMonth == data.billMonth)) {
      await deleteBill(old.id);
    }
    final past = existing.where((b) => b.data.billMonth != data.billMonth).toList();
    final result = RulesEngine(_tariffConfig(), _strings).evaluate(data, past);

    final id = _uuid.v4();
    await _imagesDir.create(recursive: true);
    final image = File('${_imagesDir.path}/$id.jpg');
    await image.writeAsBytes(jpeg, flush: true);

    final bill = Bill(
      id: id,
      connectionId: connectionId,
      data: data,
      verdict: result.verdict,
      findings: result.findings,
      imagePath: image.path,
      createdAt: DateTime.now(),
    );
    await _store.saveBill(bill);

    final c = _store.connection(connectionId);
    if (c != null && (c.disco == null || c.referenceNo == null)) {
      await _store.saveConnection(c.copyWith(disco: c.disco ?? data.disco, referenceNo: c.referenceNo ?? data.referenceNo));
    }
    _changes.add(null);
    return bill;
  }

  Future<void> deleteBill(String id) async {
    final b = _store.bill(id);
    if (b == null) return;
    final image = File(b.imagePath);
    if (await image.exists()) await image.delete();
    await _store.deleteBill(id);
    _changes.add(null);
  }

  /// Settings → "delete all data".
  Future<void> clearAll() async {
    await _store.clearData();
    if (await _imagesDir.exists()) await _imagesDir.delete(recursive: true);
    _changes.add(null);
  }
}
