/// Build-time settings, passed with --dart-define.
///
/// ```
/// flutter run --dart-define=EXTRACT_URL=https://REGION-PROJECT.cloudfunctions.net/extractBill
/// flutter run --dart-define=USE_MOCK_API=true
/// ```
class Env {
  /// Full HTTPS URL of the `extractBill` Cloud Function.
  static const extractUrl = String.fromEnvironment('EXTRACT_URL');

  /// Mock mode returns a sample bill without calling the backend (SDA §12
  /// step 5). Off unless explicitly asked for, so the app never shows sample
  /// data by accident; the app then shows a "demo mode" banner.
  static const useMockApi = bool.fromEnvironment('USE_MOCK_API');

  /// Firebase App Check (Play Integrity). Only for builds installed from
  /// Google Play: sideloaded APKs cannot pass it, so it is off by default.
  static const appCheck = bool.fromEnvironment('APP_CHECK');
}

class AppConstants {
  static const helplineNumber = '118';

  // FR-04 image compression
  static const imageLongEdgePx = 1600;
  static const imageQuality = 80;
  static const imageMaxBytes = 300 * 1024;

  // SDA §12 step 9
  static const requestTimeout = Duration(seconds: 20);

  /// Below this the extraction is treated as unreadable (SDA §9.3).
  static const minConfidence = 0.6;

  /// Below this the confirm screen asks the user to check the numbers closely.
  static const lowConfidence = 0.8;

  static const nicknameMaxLength = 24;

  static const googleTtsPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.google.android.tts';

  /// Label keys for the preset connection nicknames (FR-02).
  static const connectionPresets = ['preset_home', 'preset_shop', 'preset_parents'];
}
