import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import 'models/bill.dart';
import 'models/connection.dart';

/// On-device storage (Hive boxes `connections`, `bills`, `settings`).
/// Records are stored as JSON strings, so no generated adapters are needed.
class LocalStore {
  late Box<String> _connections;
  late Box<String> _bills;
  late Box<dynamic> _settings;

  /// Call after `Hive.initFlutter()` (app) or `Hive.init(path)` (tests).
  /// [inMemory] keeps boxes off disk, for widget tests.
  Future<void> open({bool inMemory = false}) async {
    final bytes = inMemory ? Uint8List(0) : null;
    _connections = await Hive.openBox<String>('connections', bytes: bytes);
    _bills = await Hive.openBox<String>('bills', bytes: bytes);
    _settings = await Hive.openBox<dynamic>('settings', bytes: bytes);
  }

  // ---- Connections ----

  List<Connection> connections() =>
      _connections.values.map((s) => Connection.fromJson(_decode(s))).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Connection? connection(String id) {
    final s = _connections.get(id);
    return s == null ? null : Connection.fromJson(_decode(s));
  }

  Future<void> saveConnection(Connection c) => _connections.put(c.id, jsonEncode(c.toJson()));

  Future<void> deleteConnection(String id) => _connections.delete(id);

  // ---- Bills ----

  /// Newest bill month first.
  List<Bill> billsFor(String connectionId) => _bills.values
      .map((s) => Bill.fromJson(_decode(s)))
      .where((b) => b.connectionId == connectionId)
      .toList()
    ..sort((a, b) {
      final byMonth = b.data.billMonth.compareTo(a.data.billMonth);
      return byMonth != 0 ? byMonth : b.createdAt.compareTo(a.createdAt);
    });

  Bill? bill(String id) {
    final s = _bills.get(id);
    return s == null ? null : Bill.fromJson(_decode(s));
  }

  Future<void> saveBill(Bill b) => _bills.put(b.id, jsonEncode(b.toJson()));

  Future<void> deleteBill(String id) => _bills.delete(id);

  // ---- Settings ----

  T? setting<T>(String key) => _settings.get(key) as T?;

  Future<void> setSetting(String key, Object value) => _settings.put(key, value);

  /// Deletes connections and bills; keeps device ID and onboarding flag.
  Future<void> clearData() async {
    await _connections.clear();
    await _bills.clear();
  }

  static Map<String, dynamic> _decode(String s) => jsonDecode(s) as Map<String, dynamic>;
}

/// Keys for [LocalStore.setting].
class SettingKeys {
  static const deviceId = 'device_id';
  static const onboardingDone = 'onboarding_done';
  static const slowVoice = 'slow_voice';
  static const largeText = 'large_text';
  static const ttsTipShown = 'tts_tip_shown';
}
