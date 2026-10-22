import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive_ce.dart';

import 'models/bill.dart';
import 'models/connection.dart';

/// On-device storage (Hive boxes `connections`, `bills`, `settings`),
/// AES-256 encrypted with a key kept in the Android Keystore (NFR-07).
/// Records are stored as JSON strings, so no generated adapters are needed.
class LocalStore {
  static const _boxNames = ['connections', 'bills', 'settings'];

  late Box<String> _connections;
  late Box<String> _bills;
  late Box<dynamic> _settings;

  /// Call after `Hive.initFlutter()` (app) or `Hive.init(path)` (tests).
  /// [encryptionKey] is 32 bytes; [inMemory] keeps boxes off disk for tests.
  Future<void> open({List<int>? encryptionKey, bool inMemory = false}) async {
    final cipher = encryptionKey == null ? null : HiveAesCipher(encryptionKey);
    try {
      await _openBoxes(cipher, inMemory);
    } catch (e) {
      // Unreadable data (e.g. key lost after a factory reset of the keystore):
      // start fresh rather than crash.
      debugPrint('Local data unreadable, resetting: ${e.runtimeType}');
      await Hive.close();
      for (final name in _boxNames) {
        await Hive.deleteBoxFromDisk(name);
      }
      await _openBoxes(cipher, inMemory);
    }
  }

  Future<void> _openBoxes(HiveCipher? cipher, bool inMemory) async {
    final bytes = inMemory ? Uint8List(0) : null;
    _connections = await Hive.openBox<String>('connections', encryptionCipher: cipher, bytes: bytes);
    _bills = await Hive.openBox<String>('bills', encryptionCipher: cipher, bytes: bytes);
    _settings = await Hive.openBox<dynamic>('settings', encryptionCipher: cipher, bytes: bytes);
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

  /// Deletes connections and bills; keeps device ID and preferences.
  Future<void> clearData() async {
    await _connections.clear();
    await _bills.clear();
    await _connections.compact();
    await _bills.compact();
  }

  static Map<String, dynamic> _decode(String s) => jsonDecode(s) as Map<String, dynamic>;
}

/// Keys for [LocalStore.setting].
class SettingKeys {
  static const deviceId = 'device_id';
  static const onboardingDone = 'onboarding_done';
  static const language = 'language';
  static const slowVoice = 'slow_voice';
  static const largeText = 'large_text';
  static const ttsTipShown = 'tts_tip_shown';
}

/// The Hive encryption key, generated once and kept in the Android Keystore.
class StorageKey {
  static const _name = 'bill_samjho_hive_key_v1';
  static const _storage = FlutterSecureStorage();

  static Future<List<int>> load() async {
    final existing = await _storage.read(key: _name);
    if (existing != null) return base64Url.decode(existing);
    final key = Hive.generateSecureKey();
    await _storage.write(key: _name, value: base64UrlEncode(key));
    return key;
  }
}
