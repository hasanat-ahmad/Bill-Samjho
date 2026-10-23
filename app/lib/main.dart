import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/constants.dart';
import 'core/firebase_gate.dart';
import 'core/i18n.dart';
import 'data/api_service.dart';
import 'data/bill_chat.dart';
import 'data/bill_repository.dart';
import 'data/local_store.dart';
import 'data/tariff_config_service.dart';
import 'services/scan_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Never wait for Firebase before the first screen.
  final firebase = FirebaseGate(_initFirebase());

  await Hive.initFlutter();
  final store = LocalStore();
  await _openStore(store);

  final translations = {
    for (final lang in AppLanguage.values)
      lang: AppStrings(
        lang,
        jsonDecode(await rootBundle.loadString('assets/i18n/${lang.name}.json')) as Map<String, dynamic>,
      ),
  };

  final tariffs = TariffConfigService();
  await tariffs.loadBundled();
  unawaited(firebase.ready.then((ok) => ok ? tariffs.connectRemote() : null));

  final docs = await getApplicationDocumentsDirectory();
  final repo = BillRepository(
    store: store,
    api: ApiService.create(
      firebase: firebase,
      appCheckToken: Env.appCheck
          ? () async => await firebase.ready ? FirebaseAppCheck.instance.getToken() : null
          : null,
    ),
    tariffConfig: () => tariffs.config,
    imagesDir: Directory('${docs.path}/bills'),
  );

  final tts = TtsService();
  unawaited(tts.init(
    language: AppLanguage.fromCode(store.setting<String>(SettingKeys.language)),
    slow: store.setting<bool>(SettingKeys.slowVoice) ?? false,
  ));

  final version = await PackageInfo.fromPlatform().then((p) => p.version, onError: (_) => '');

  runApp(BillSamjhoApp(
    store: store,
    repo: repo,
    translations: translations,
    tts: tts,
    scanner: ScanService(),
    chat: ChatAvailability((prompt) => FirebaseBillChat(prompt, firebase), firebase: firebase),
    appVersion: version,
  ));
}

/// Opens the encrypted store. If the Keystore is unusable the app still runs,
/// keeping data in memory only rather than writing it unencrypted.
Future<void> _openStore(LocalStore store) async {
  try {
    await store.open(encryptionKey: await StorageKey.load());
  } catch (e) {
    debugPrint('Secure storage unavailable: ${e.runtimeType}');
    await store.open(inMemory: true);
  }
}

/// Firebase is optional: without android/app/google-services.json the app
/// uses the bundled tariff config and skips crash reporting and App Check.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    // Only touch App Check when enabled: once created it is attached to
    // every Firebase AI request, and sideloaded APKs cannot pass it.
    if (Env.appCheck) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kReleaseMode ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
      );
    }
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    return true;
  } catch (e) {
    debugPrint('Firebase not configured: ${e.runtimeType}');
    return false;
  }
}
