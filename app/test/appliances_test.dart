import 'dart:convert';
import 'dart:io';

import 'package:bill_samjho/core/i18n.dart';
import 'package:bill_samjho/data/models/extracted_bill.dart';
import 'package:bill_samjho/data/models/tariff_config.dart';
import 'package:bill_samjho/domain/appliances.dart';
import 'package:bill_samjho/domain/forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final config = TariffConfig.fromJson(_json('assets/tariff_config_default.json'));
  Appliance find(String key) => Appliance.all.firstWhere((a) => a.key == key);

  test('units: watts × hours × 30 days × count', () {
    // 80 W fan, 12 h a day, 2 fans: 80 × 12 × 30 × 2 / 1000 = 57.6
    expect(ApplianceUse(find('fan'), count: 2, hoursPerDay: 12).monthlyUnits, 58);
    // 1.5 ton AC, 6 h: 1500 × 6 × 30 / 1000 = 270
    expect(ApplianceUse(find('ac'), hoursPerDay: 6).monthlyUnits, 270);
    // A fridge's compressor runs about half the time: 150 × 0.5 × 24 × 30 / 1000 = 54
    expect(ApplianceUse(find('fridge'), hoursPerDay: 24).monthlyUnits, 54);
  });

  test('cost at the bill\'s own rates, jumping above the protected limit', () {
    const bill = ExtractedBill(billMonth: '2026-09', units: 100, totalDue: 2000, protectedConsumer: true);
    final f = Forecaster(config);
    expect(f.costAt(bill, const [], 100), closeTo(2000, 0.01)); // same units, same bill
    final at150 = f.costAt(bill, const [], 150)!;
    final at250 = f.costAt(bill, const [], 250)!;
    expect(at150, greaterThan(2000));
    // Past 200 units every unit is billed at the higher non-protected rate.
    expect(at250 / at150, greaterThan(250 / 150 * 1.5));
    expect(f.costAt(const ExtractedBill(billMonth: 'Sept', units: 100, totalDue: 2000), const [], 150), isNull);
  });

  test('every appliance has a name in both languages', () {
    final en = AppStrings(AppLanguage.en, _json('assets/i18n/en.json'));
    final ur = AppStrings(AppLanguage.ur, _json('assets/i18n/ur.json'));
    for (final a in Appliance.all) {
      expect(en.t('appliance_${a.key}'), isNot('appliance_${a.key}'));
      expect(ur.t('appliance_${a.key}'), isNot('appliance_${a.key}'));
    }
  });
}
