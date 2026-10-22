import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/tariff_config.dart';

/// Tariff config from Firebase Remote Config (`tariff_config`), falling back
/// to the bundled assets/tariff_config_default.json when offline (FR-18).
class TariffConfigService {
  static const _remoteKey = 'tariff_config';
  static const _assetPath = 'assets/tariff_config_default.json';

  late TariffConfig _config;
  late String _bundled;
  TariffConfig get config => _config;

  /// Loads the bundled copy; call before the first screen.
  Future<void> loadBundled() async {
    _bundled = await rootBundle.loadString(_assetPath);
    _config = TariffConfig.fromJson(jsonDecode(_bundled) as Map<String, dynamic>);
  }

  /// Switches to Remote Config once Firebase is ready (in the background).
  Future<void> connectRemote() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults({_remoteKey: _bundled});
      await rc.activate();
      _applyRemote(rc);
      unawaited(rc.fetchAndActivate().then((_) => _applyRemote(rc)).catchError((Object e) {
        debugPrint('Remote Config fetch failed: $e');
      }));
    } catch (e) {
      debugPrint('Remote Config unavailable, using bundled tariffs: $e');
    }
  }

  void _applyRemote(FirebaseRemoteConfig rc) {
    try {
      final raw = rc.getString(_remoteKey);
      _config = TariffConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // Malformed remote JSON: keep the previous config.
      debugPrint('Ignoring invalid remote tariff_config: $e');
    }
  }
}
