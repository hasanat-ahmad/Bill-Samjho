import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bill_samjho/app.dart';
import 'package:bill_samjho/core/constants.dart';
import 'package:bill_samjho/data/api_service.dart';
import 'package:bill_samjho/data/bill_repository.dart';
import 'package:bill_samjho/data/local_store.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:bill_samjho/data/models/urdu_strings.dart';
import 'package:bill_samjho/services/scan_service.dart';
import 'package:bill_samjho/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive_ce.dart';

Map<String, dynamic> _asset(String name) =>
    jsonDecode(File('assets/$name').readAsStringSync()) as Map<String, dynamic>;

class FakeScanService extends ScanService {
  @override
  Future<String?> scan() async => '/fake/bill.jpg';

  @override
  Future<Uint8List> compress(String path) async => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
}

Future<void> goBack(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
  await tester.pumpAndSettle();
}

void main() {
  late Directory tmp;
  late LocalStore store;
  late BillRepository repo;
  late UrduStrings strings;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bill_samjho_flow');
    Hive.init('${tmp.path}/hive');
    store = LocalStore();
    await store.open(inMemory: true);
    strings = UrduStrings(_asset('urdu_strings.json'));
    repo = BillRepository(
      store: store,
      api: MockApiService(),
      tariffConfig: () => TariffConfig.fromJson(_asset('tariff_config_default.json')),
      strings: strings,
      imagesDir: Directory('${tmp.path}/images'),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('UC-1: intro → new bill → confirm → result → complaint', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160); // ~5.5" phone
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BillSamjhoApp(
      store: store,
      repo: repo,
      strings: strings,
      tts: TtsService(),
      scanner: FakeScanService(),
    ));
    await tester.pumpAndSettle();

    // S1 intro, right-to-left
    expect(find.text(Labels.privacy), findsOneWidget);
    expect(Directionality.of(tester.element(find.text(Labels.start))), TextDirection.rtl);
    await tester.runAsync(() async {
      await tester.tap(find.text(Labels.start));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    // S2 home, empty
    expect(find.text(Labels.scanFirstBill), findsOneWidget);

    // Tap 1: new bill. Tap 2: preset connection → scan starts.
    await tester.tap(find.text(Labels.newBill));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(AppConstants.connectionPresets.first));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
    expect(find.text(Labels.readingBill), findsOneWidget);

    // Mock API answers after 2 s → S5 confirm with the sample values.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(Labels.confirmTitle), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '186'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '5867'), findsOneWidget);

    // Correct the units (Alt 5a), using Urdu digits: ۱۹۰ → 190.
    await tester.enterText(find.widgetWithText(TextFormField, '186'), '۱۹۰');
    expect(find.widgetWithText(TextFormField, '190'), findsOneWidget);

    // Tap 3: confirm → S6 result.
    await tester.runAsync(() async {
      await tester.tap(find.text(Labels.ok));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text(Labels.listenAll), findsOneWidget);
    expect(find.text('5,867'), findsOneWidget);
    // Sample bill history has July at 212 units → protected lost → "check".
    expect(find.text(Labels.verdictCheck), findsOneWidget);
    // No Urdu voice in tests → one-time install tip shown.
    expect(find.text(Labels.ttsTip), findsOneWidget);
    final summary = find.textContaining('اس مہینے آپ نے 190 یونٹ');
    await tester.scrollUntilVisible(summary, 300);
    expect(summary, findsOneWidget);

    // S7 complaint sheet with reference number.
    await tester.scrollUntilVisible(find.text(Labels.complain), 300);
    await tester.tap(find.text(Labels.complain));
    await tester.pumpAndSettle();
    expect(find.text(Labels.complaintTitle), findsOneWidget);
    expect(find.textContaining('07 11234 1234567 U'), findsOneWidget);
    expect(find.text(Labels.call118), findsOneWidget);

    // Saved under the connection.
    final connection = repo.connections().single;
    expect(connection.nickname, AppConstants.connectionPresets.first);
    expect(repo.billsFor(connection.id).single.data.units, 190);
  });

  testWidgets('home card, history chart and glossary render', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await store.setSetting(SettingKeys.onboardingDone, true);
      final c = await repo.addConnection('دکان');
      await repo.analyseAndSave(
        connectionId: c.id,
        data: (await MockApiService().extractBill(Uint8List(0), '')),
        jpeg: Uint8List.fromList([1, 2, 3]),
      );
    });

    await tester.pumpWidget(BillSamjhoApp(
      store: store,
      repo: repo,
      strings: strings,
      tts: TtsService(),
      scanner: FakeScanService(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('دکان'), findsOneWidget);
    expect(find.text(Labels.verdictCheck), findsOneWidget);

    await tester.tap(find.text('دکان'));
    await tester.pumpAndSettle();
    expect(find.text(Labels.history), findsWidgets);
    expect(find.text('ستمبر 2026'), findsOneWidget);

    await goBack(tester);
    await tester.tap(find.byTooltip(Labels.glossary));
    await tester.pumpAndSettle();
    expect(find.text('فیول پرائس ایڈجسٹمنٹ'), findsOneWidget);

    await goBack(tester);
    await tester.tap(find.byTooltip(Labels.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Labels.large));
    await tester.pumpAndSettle();
    expect(store.setting<bool>(SettingKeys.largeText), isTrue);
  });
}
