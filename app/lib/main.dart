import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/api_service.dart';
import 'data/bill_repository.dart';
import 'data/local_store.dart';
import 'data/models/urdu_strings.dart';
import 'data/tariff_config_service.dart';
import 'services/scan_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initFirebase();

  await Hive.initFlutter();
  final store = LocalStore();
  await store.open();

  final strings = UrduStrings(
    jsonDecode(await rootBundle.loadString('assets/urdu_strings.json')) as Map<String, dynamic>,
  );
  final tariffs = TariffConfigService();
  await tariffs.load(firebaseReady: firebaseReady);

  final docs = await getApplicationDocumentsDirectory();
  final repo = BillRepository(
    store: store,
    api: ApiService.create(),
    tariffConfig: () => tariffs.config,
    strings: strings,
    imagesDir: Directory('${docs.path}/bills'),
  );

  final tts = TtsService();
  unawaited(tts.init(slow: store.setting<bool>(SettingKeys.slowVoice) ?? false));

  runApp(BillSamjhoApp(
    store: store,
    repo: repo,
    strings: strings,
    tts: tts,
    scanner: ScanService(),
  ));
}

/// Firebase is optional: without android/app/google-services.json the app
/// uses the bundled tariff config and skips crash reporting.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    return true;
  } catch (e) {
    debugPrint('Firebase not configured: $e');
    return false;
  }
}
