import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../domain/rules_engine.dart';
import 'api_service.dart';
import 'local_store.dart';
import 'models/bill.dart';
import 'models/connection.dart';
import 'models/extracted_bill.dart';
import 'models/tariff_config.dart';

/// Single entry point for connections and bills.
class BillRepository {
  BillRepository({
    required LocalStore store,
    required ApiService api,
    required TariffConfig Function() tariffConfig,
    required Directory imagesDir,
  })  : _store = store,
        _api = api,
        _tariffConfig = tariffConfig,
        _imagesDir = imagesDir;

  final LocalStore _store;
  final ApiService _api;
  final TariffConfig Function() _tariffConfig;
  final Directory _imagesDir;
  final _changes = StreamController<void>.broadcast();
  static const _uuid = Uuid();

  TariffConfig get tariffConfig => _tariffConfig();

  /// True when bills come from the sample data, not the real backend.
  bool get isDemo => _api.isMock;

  /// False until the photo-reading backend is configured for this build.
  bool get canScanPhotos => _api.available;

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

  static final _unsafeChars = RegExp(r'[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069]');

  /// Removes control and bidi-override characters and caps the length.
  static String cleanNickname(String raw) {
    final s = raw.replaceAll(_unsafeChars, '').trim();
    return String.fromCharCodes(s.runes.take(AppConstants.nicknameMaxLength)).trim();
  }

  /// Throws [ArgumentError] if the nickname is empty after cleaning.
  Future<Connection> addConnection(String nickname) async {
    final name = cleanNickname(nickname);
    if (name.isEmpty) throw ArgumentError.value(nickname, 'nickname');
    final c = Connection(id: _uuid.v4(), nickname: name, createdAt: DateTime.now());
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

  /// Remembers the meter's reference number and company for next time.
  Future<void> saveReference(String connectionId, {required String referenceNo, required String disco}) async {
    final c = _store.connection(connectionId);
    if (c == null) return;
    await _store.saveConnection(Connection(
      id: c.id,
      nickname: c.nickname,
      disco: disco,
      referenceNo: referenceNo,
      createdAt: c.createdAt,
    ));
    _changes.add(null);
  }

  /// Reads a bill page's text with the AI backend, when a PITC page layout
  /// is not recognised. Throws [ApiException].
  Future<ExtractedBill> extractText(String text) => _api.extractBillText(text, deviceId);

  // ---- Bills ----

  /// Newest month first.
  List<Bill> billsFor(String connectionId) => _store.billsFor(connectionId);

  Bill? latestBill(String connectionId) {
    final bills = billsFor(connectionId);
    return bills.isEmpty ? null : bills.first;
  }

  Bill? bill(String id) => _store.bill(id);

  /// Throws [ApiException].
  Future<ExtractedBill> extract(Uint8List jpeg, {ProgressCallback? onProgress}) =>
      _api.extractBill(jpeg, deviceId, onProgress: onProgress);

  /// Runs the rules engine on the (possibly user-corrected) [data], then saves
  /// the bill and its image. A rescan of the same month replaces the old bill.
  /// [jpeg] is null for bills read from PITC's website (no photo).
  Future<Bill> analyseAndSave({
    required String connectionId,
    required ExtractedBill data,
    Uint8List? jpeg,
  }) async {
    final existing = billsFor(connectionId);
    for (final old in existing.where((b) => b.data.billMonth == data.billMonth)) {
      await deleteBill(old.id);
    }
    final past = existing.where((b) => b.data.billMonth != data.billMonth).toList();
    final result = RulesEngine(_tariffConfig()).evaluate(data, past);

    final id = _uuid.v4();
    var imagePath = '';
    if (jpeg != null) {
      await _imagesDir.create(recursive: true);
      final image = File('${_imagesDir.path}/$id.jpg');
      await image.writeAsBytes(jpeg, flush: true);
      imagePath = image.path;
    }

    final bill = Bill(
      id: id,
      connectionId: connectionId,
      data: data,
      verdict: result.verdict,
      findings: result.findings,
      imagePath: imagePath,
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
    if (b.imagePath.isNotEmpty) {
      final image = File(b.imagePath);
      if (await image.exists()) await image.delete();
    }
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
