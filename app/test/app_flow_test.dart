import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/app.dart';
import 'package:bill_samjho/core/i18n.dart';
import 'package:bill_samjho/data/api_service.dart';
import 'package:bill_samjho/data/bill_repository.dart';
import 'package:bill_samjho/data/local_store.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:bill_samjho/services/scan_service.dart';
import 'package:bill_samjho/services/tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive_ce.dart';

Map<String, dynamic> _json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final _jpeg = File('test/fixtures/bill.jpg').readAsBytesSync();

class FakeScanService extends ScanService {
  @override
  Future<String?> scan() async => '/fake/bill.jpg';

  @override
  Future<Uint8List> compress(String path) async => _jpeg;

  @override
  Future<void> discard(String path) async {}
}

Future<void> goBack(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
  await tester.pumpAndSettle();
}

/// Taps something whose handler does real (non-fake-clock) async work.
Future<void> tapAsync(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory tmp;
  late LocalStore store;
  late BillRepository repo;
  final translations = {
    for (final l in AppLanguage.values) l: AppStrings(l, _json('assets/i18n/${l.name}.json')),
  };

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bill_samjho_flow');
    Hive.init('${tmp.path}/hive');
    store = LocalStore();
    await store.open(inMemory: true);
    repo = BillRepository(
      store: store,
      api: MockApiService(),
      tariffConfig: () => TariffConfig.fromJson(_json('assets/tariff_config_default.json')),
      imagesDir: Directory('${tmp.path}/images'),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Small phone: 360 × 720 dp. Overflows fail the test.
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BillSamjhoApp(
      store: store,
      repo: repo,
      translations: translations,
      tts: TtsService(),
      scanner: FakeScanService(),
      appVersion: '1.0.0',
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('UC-1 in English (default): intro → scan → confirm → result → complaint', (tester) async {
    await pumpApp(tester);

    // S1: English by default, left-to-right.
    expect(find.text('Understand your electricity bill'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Get started'))), TextDirection.ltr);
    await tapAsync(tester, find.text('Get started'));

    // S2: empty home with demo banner (mock API).
    expect(find.text('Scan your first bill'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    // Tap 1: scan. Tap 2: preset meter → scanner → upload.
    await tester.tap(find.text('Scan new bill'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Home'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Mock API answers → S5 confirm with the sample values and the photo.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Check the numbers'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '186'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '5867'), findsOneWidget);

    // Alt 5a: correct the units with Urdu-keyboard digits ۱۹۰ → 190.
    await tester.enterText(find.widgetWithText(TextFormField, '186'), '۱۹۰');
    expect(find.widgetWithText(TextFormField, '190'), findsOneWidget);

    // Tap 3: confirm → S6 result.
    await tapAsync(tester, find.text('Looks right'));
    expect(find.text('Listen to explanation'), findsOneWidget);
    expect(find.text('Rs 5,867'), findsOneWidget);
    // Sample history has July at 212 units → protected rate lost → "Check this".
    expect(find.text('Check this'), findsOneWidget);
    final summary = find.textContaining('This month you used 190 units');
    await tester.scrollUntilVisible(summary, 300);
    expect(summary, findsOneWidget);

    // S7 complaint sheet with the reference number.
    await tester.scrollUntilVisible(find.text('Make a complaint'), 300);
    await tester.ensureVisible(find.text('Make a complaint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make a complaint'));
    await tester.pumpAndSettle();
    expect(find.text('Complaint message'), findsOneWidget);
    expect(find.textContaining('07 11234 1234567 U'), findsOneWidget);
    expect(find.text('Call 118'), findsOneWidget);

    final connection = repo.connections().single;
    expect(connection.nickname, 'Home');
    expect(repo.billsFor(connection.id).single.data.units, 190);
  });

  testWidgets('switching to Urdu flips the app right-to-left', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(find.text('شروع کریں'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('شروع کریں'))), TextDirection.rtl);
    expect(store.setting<String>(SettingKeys.language), 'ur');

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('home, history, glossary, settings in both languages; saved bill re-renders', (tester) async {
    await tester.runAsync(() async {
      await store.setSetting(SettingKeys.onboardingDone, true);
      final c = await repo.addConnection('Shop');
      await repo.analyseAndSave(
        connectionId: c.id,
        data: await MockApiService().extractBill(Uint8List(0), ''),
        jpeg: _jpeg,
      );
    });
    await pumpApp(tester);

    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Rs 5,867'), findsOneWidget);
    expect(find.text('Check this'), findsOneWidget);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.text('Units per month'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);

    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Amount due'), findsOneWidget);
    await goBack(tester);
    await goBack(tester);

    await tester.tap(find.byTooltip('Bill terms'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel Price Adjustment'), findsOneWidget);
    await goBack(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Version 1.0.0'), 300);
    expect(find.text('Version 1.0.0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Large'), -300);
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(store.setting<bool>(SettingKeys.largeText), isTrue);

    // Large text in Urdu must still lay out without overflow.
    await tester.scrollUntilVisible(find.text('اردو'), -300);
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(find.text('سیٹنگز'), findsOneWidget);
    await goBack(tester);
    expect(find.text('5,867 روپے'), findsOneWidget);
    expect(find.text('دیکھیں'), findsOneWidget);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ستمبر 2026'), 300);
    await tester.tap(find.text('ستمبر 2026'));
    await tester.pumpAndSettle();
    // The saved bill is explained in Urdu now, from the same stored data.
    final urduSummary = find.textContaining('اس مہینے آپ نے 186 یونٹ');
    await tester.scrollUntilVisible(urduSummary, 300);
    expect(urduSummary, findsOneWidget);
  });
}
