import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bill_samjho/data/api_service.dart';
import 'package:bill_samjho/data/bill_repository.dart';
import 'package:bill_samjho/data/local_store.dart';
import 'package:bill_samjho/data/models/extracted_bill.dart';
import 'package:bill_samjho/data/models/finding.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

Map<String, dynamic> _asset(String name) =>
    jsonDecode(File('assets/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  late Directory tmp;
  late LocalStore store;
  late BillRepository repo;
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
  final config = TariffConfig.fromJson(_asset('tariff_config_default.json'));

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bill_samjho_test');
    Hive.init('${tmp.path}/hive');
    store = LocalStore();
    await store.open();
    repo = BillRepository(
      store: store,
      api: MockApiService(),
      tariffConfig: () => config,
      imagesDir: Directory('${tmp.path}/images'),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  ExtractedBill data(String month, int units) =>
      ExtractedBill(billMonth: month, units: units, totalDue: 2000, referenceNo: 'REF1', disco: 'IESCO');

  test('device ID is generated once and reused', () {
    final id = repo.deviceId;
    expect(id, isNotEmpty);
    expect(repo.deviceId, id);
  });

  test('add connection and list in creation order', () async {
    await repo.addConnection(' Ghar ');
    await repo.addConnection('Dukaan');
    expect(repo.connections().map((c) => c.nickname), ['Ghar', 'Dukaan']);
  });

  test('nicknames are cleaned: control and bidi characters removed, length capped', () async {
    final c = await repo.addConnection('  Gh\u202Ear\u0000  ');
    expect(c.nickname, 'Ghar');
    final long = await repo.addConnection('x' * 100);
    expect(long.nickname.length, 24);
    await expectLater(repo.addConnection(' \u200F '), throwsArgumentError);
  });

  test('analyseAndSave stores bill, image and fills connection details', () async {
    final c = await repo.addConnection('Ghar');
    final bill = await repo.analyseAndSave(connectionId: c.id, data: data('2026-09', 150), jpeg: jpeg);

    expect(File(bill.imagePath).existsSync(), isTrue);
    expect(repo.bill(bill.id)!.data.units, 150);
    expect(repo.bill(bill.id)!.findings.first.isSummary, isTrue);
    expect(repo.connection(c.id)!.referenceNo, 'REF1');
    expect(repo.connection(c.id)!.disco, 'IESCO');
  });

  test('past saved bills feed the rules engine', () async {
    final c = await repo.addConnection('Ghar');
    await repo.analyseAndSave(connectionId: c.id, data: data('2026-08', 100), jpeg: jpeg);
    final bill = await repo.analyseAndSave(connectionId: c.id, data: data('2026-09', 250), jpeg: jpeg);
    expect(bill.findings.map((f) => f.ruleId), contains('R2'));
    expect(bill.verdict, Verdict.wrong);
  });

  test('bills listed newest month first; same month rescan replaces', () async {
    final c = await repo.addConnection('Ghar');
    await repo.analyseAndSave(connectionId: c.id, data: data('2026-07', 100), jpeg: jpeg);
    final first = await repo.analyseAndSave(connectionId: c.id, data: data('2026-08', 110), jpeg: jpeg);
    await repo.analyseAndSave(connectionId: c.id, data: data('2026-08', 120), jpeg: jpeg);

    expect(repo.billsFor(c.id).map((b) => b.data.units), [120, 100]);
    expect(File(first.imagePath).existsSync(), isFalse);
    expect(repo.latestBill(c.id)!.data.billMonth, '2026-08');
  });

  test('delete bill removes record and image', () async {
    final c = await repo.addConnection('Ghar');
    final bill = await repo.analyseAndSave(connectionId: c.id, data: data('2026-09', 150), jpeg: jpeg);
    await repo.deleteBill(bill.id);
    expect(repo.bill(bill.id), isNull);
    expect(File(bill.imagePath).existsSync(), isFalse);
  });

  test('delete connection removes its bills only', () async {
    final a = await repo.addConnection('Ghar');
    final b = await repo.addConnection('Dukaan');
    await repo.analyseAndSave(connectionId: a.id, data: data('2026-09', 150), jpeg: jpeg);
    await repo.analyseAndSave(connectionId: b.id, data: data('2026-09', 90), jpeg: jpeg);

    await repo.deleteConnection(a.id);
    expect(repo.connections().map((c) => c.nickname), ['Dukaan']);
    expect(repo.billsFor(a.id), isEmpty);
    expect(repo.billsFor(b.id), hasLength(1));
  });

  test('clearAll removes data but keeps device ID', () async {
    final id = repo.deviceId;
    final c = await repo.addConnection('Ghar');
    await repo.analyseAndSave(connectionId: c.id, data: data('2026-09', 150), jpeg: jpeg);
    await repo.clearAll();
    expect(repo.connections(), isEmpty);
    expect(repo.billsFor(c.id), isEmpty);
    expect(repo.deviceId, id);
  });

  test('bill JSON round-trips through storage', () async {
    final c = await repo.addConnection('Ghar');
    final sample = ExtractedBill.fromJson(MockApiService.sampleBillJson);
    final bill = await repo.analyseAndSave(connectionId: c.id, data: sample, jpeg: jpeg);
    final loaded = repo.bill(bill.id)!;
    expect(loaded.data.toJson(), sample.toJson());
    expect(loaded.findings.map((f) => f.toJson()), bill.findings.map((f) => f.toJson()));
    expect(loaded.verdict, bill.verdict);
  });
}
