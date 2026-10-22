import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/data/pitc/pitc.dart';
import 'package:bill_samjho/data/pitc/pitc_bill_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures are the real output of assets/pitc/read_bill.js run in Chrome on
/// sample bill pages (and on PITC's own "invalid reference" page).
PitcPage _page(String name) => PitcPage.fromJson(
      jsonDecode(File('test/fixtures/pitc/$name.json').readAsStringSync()) as Map<String, dynamic>,
    );

void main() {
  group('reference number', () {
    test('accepts 14 digits with spaces, dashes and Urdu digits', () {
      expect(ReferenceNumber.parse('07 11234 1234567 U')!.digits, '07112341234567');
      expect(ReferenceNumber.parse('07-11234-1234567')!.rural, isFalse);
      expect(ReferenceNumber.parse('26 13115 0123456 R')!.rural, isTrue);
      expect(ReferenceNumber.parse('۰۷۱۱۲۳۴۱۲۳۴۵۶۷')!.digits, '07112341234567');
      expect(ReferenceNumber.parse('07112341234567')!.display, '07 11234 1234567 U');
    });

    test('rejects anything that is not 14 digits', () {
      expect(ReferenceNumber.parse(''), isNull);
      expect(ReferenceNumber.parse('0711234123456'), isNull);
      expect(ReferenceNumber.parse('071123412345678'), isNull);
      expect(ReferenceNumber.parse('abc'), isNull);
    });
  });

  group('companies and site', () {
    test('all 11 PITC companies, found by name', () {
      expect(Disco.all, hasLength(11));
      expect(Disco.find('PESCO')!.billPage.toString(), 'https://bill.pitc.com.pk/pescobill');
      expect(Disco.find('Lahore Electric Supply Company (LESCO)')!.code, 'LESCO');
      expect(Disco.find('K-Electric'), isNull);
    });

    test('in-app browser is limited to PITC over HTTPS', () {
      expect(PitcSite.isAllowed(Uri.parse('https://bill.pitc.com.pk/pescobill')), isTrue);
      expect(PitcSite.isAllowed(Uri.parse('http://bill.pitc.com.pk/pescobill')), isFalse);
      expect(PitcSite.isAllowed(Uri.parse('https://bill.pitc.com.pk.evil.example/x')), isFalse);
      expect(PitcSite.isAllowed(Uri.parse('https://example.com')), isFalse);
    });
  });

  group('bill page parser', () {
    test('header-row layout with text history (LESCO style)', () {
      final page = _page('bill_a');
      expect(page.looksLikeBill, isTrue);
      final b = PitcBillParser.parse(page, disco: 'LESCO')!;
      expect(b.disco, 'LESCO');
      expect(b.billMonth, '2026-09');
      expect(b.units, 186);
      expect(b.totalDue, 7233);
      expect(b.dueDate, '2026-10-15');
      expect(b.referenceNo, '07 11234 1234567 U');
      expect(b.previousReading, 18420);
      expect(b.presentReading, 18606);
      expect(b.energyCharges, 5377.26);
      expect(b.fixedCharges, 600);
      expect(b.fpa, 152.40);
      expect(b.gst, 1103.34);
      expect(b.lateSurcharge, 723);
      expect(b.confidence, 1.0);
      expect(b.history, hasLength(12));
      expect(b.history.first.month, '2025-09');
      expect(b.history.first.units, 165);
      expect(b.history.map((h) => h.month), contains('2026-07'));
    });

    test('label-value layout, history table and credit total (PESCO style)', () {
      final b = PitcBillParser.parse(_page('bill_b'), disco: 'PESCO')!;
      expect(b.billMonth, '2026-03');
      expect(b.dueDate, '2026-04-14');
      expect(b.units, 48);
      expect(b.totalDue, -297); // "297 CR"
      expect(b.isCredit, isTrue);
      expect(b.arrears, -520);
      expect(b.energyCharges, 189.60);
      expect(b.referenceNo, '26 13115 0123456 R');
      expect(b.previousReading, 5120);
      expect(b.presentReading, 5168);
      expect(b.history.map((h) => h.month), ['2025-03', '2025-04', '2026-02']);
    });

    test("PITC's 2026 layout (real PESCO page, anonymised): no tables, label lines", () {
      final page = _page('pesco_2026_layout');
      expect(page.tables.expand((t) => t), isEmpty);
      expect(page.looksLikeBill, isTrue);
      final b = PitcBillParser.parse(page, disco: 'PESCO')!;
      expect(b.billMonth, '2026-09');
      expect(b.dueDate, '2026-10-14');
      expect(b.units, 106);
      expect(b.totalDue, 4367);
      expect(b.referenceNo, '26 11111 2222222');
      expect(b.previousReading, 249);
      expect(b.presentReading, 355);
      expect(b.tariffCategory, 'A-1A(01)');
      expect(b.arrears, 0);
      expect(b.fpa, 0);
      expect(b.protectedConsumer, isFalse); // "CATEGORY Unprotected"
      // "Total Electricity Charges" is not the energy charge: no false alarm.
      expect(b.energyCharges, isNull);
    });

    test('bank-copy line is a fallback for month, reference, total and due date', () {
      const page = PitcPage(
        text: 'UNITS\n106\nSEP 26 - 26 11111 2222222 - 000004367 - 14 OCT 26 - 000004550 - 191026 - 6',
        tables: [],
      );
      final b = PitcBillParser.parse(page)!;
      expect(b.billMonth, '2026-09');
      expect(b.totalDue, 4367);
      expect(b.dueDate, '2026-10-14');
      expect(b.referenceNo, '26 11111 2222222');
    });

    test("PITC's invalid-reference page is not a bill", () {
      final page = _page('invalid');
      expect(page.looksLikeBill, isFalse);
      expect(PitcBillParser.parse(page), isNull);
    });

    test('missing required values give null, not a guess', () {
      const page = PitcPage(text: 'UNITS CONSUMED 48', tables: [
        [
          ['UNITS CONSUMED', '48'],
        ],
      ]);
      expect(PitcBillParser.parse(page), isNull);
    });
  });
}
