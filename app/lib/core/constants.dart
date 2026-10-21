/// Build-time settings, passed with --dart-define.
///
/// ```
/// flutter run --dart-define=EXTRACT_URL=https://REGION-PROJECT.cloudfunctions.net/extractBill
/// flutter run --dart-define=USE_MOCK_API=true
/// ```
class Env {
  /// Full URL of the `extractBill` Cloud Function.
  static const extractUrl = String.fromEnvironment('EXTRACT_URL');

  /// Mock mode returns a sample bill without calling the backend (SDA §12 step 5).
  /// Defaults to true while no backend URL is configured.
  static const useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: extractUrl == '');
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

  static const googleTtsPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.google.android.tts';

  static const connectionPresets = ['گھر', 'دکان', 'امی ابو کا گھر'];
}

/// Fixed UI labels. Bill explanations live in assets/urdu_strings.json.
class Labels {
  static const appName = 'بل سمجھو';
  static const tagline = 'بجلی کے بل کی تصویر لیں، ہم آسان اردو میں بتائیں گے کہ بل ٹھیک لگ رہا ہے یا نہیں۔';
  static const privacy =
      'آپ کے بل کی تصویر صرف پڑھنے کے لیے بھیجی جاتی ہے، پھر مٹا دی جاتی ہے۔ آن لائن کچھ محفوظ نہیں ہوتا۔';
  static const unofficial = 'یہ سرکاری ایپ نہیں ہے۔ یہ صرف مشورہ دیتی ہے۔';
  static const start = 'شروع کریں';
  static const listen = 'سنیں';

  static const newBill = 'نیا بل';
  static const scanFirstBill = 'اپنا پہلا بل اسکین کریں';
  static const scanFirstBillHint = 'نیچے "نیا بل" کا بٹن دبائیں';
  static const glossary = 'چارجز کا مطلب';
  static const settings = 'سیٹنگز';
  static const units = 'یونٹ';
  static const rupees = 'روپے';
  static const noBillYet = 'ابھی کوئی بل نہیں';

  static const pickConnection = 'کس میٹر کا بل ہے؟';
  static const newConnection = 'نیا کنکشن';
  static const nicknameHint = 'یا اپنا نام لکھیں';
  static const add = 'شامل کریں';
  static const fromGallery = 'گیلری سے تصویر چنیں';

  static const takePhoto = 'بل کی تصویر لیں';
  static const readingBill = 'بل پڑھ رہے ہیں...';
  static const readingBillWait = 'تھوڑا انتظار کریں';
  static const cancel = 'منسوخ کریں';
  static const retake = 'دوبارہ تصویر لیں';
  static const tryAgain = 'دوبارہ کوشش کریں';
  static const goBack = 'واپس جائیں';

  static const confirmTitle = 'کیا یہ نمبر ٹھیک ہیں؟';
  static const confirmHint = 'اگر کوئی نمبر غلط ہے تو اسے کاغذ والے بل سے درست کر دیں۔';
  static const confirmLowConfidence = 'تصویر پوری طرح صاف نہیں تھی، نمبر غور سے ملا لیں۔';
  static const month = 'مہینہ';
  static const totalAmount = 'کل رقم';
  static const dueDate = 'آخری تاریخ';
  static const invalidNumber = 'صحیح نمبر لکھیں';
  static const ok = 'ٹھیک ہے';

  static const verdictNormal = 'ٹھیک ہے';
  static const verdictCheck = 'دیکھیں';
  static const verdictWrong = 'شاید غلط';
  static const listenAll = 'پورا بل سنیں';
  static const stop = 'روکیں';
  static const meterTitle = '200 یونٹ میٹر';
  static const complain = 'شکایت';
  static const ttsTip = 'اردو آواز کے لیے Google Speech Services انسٹال کریں';
  static const install = 'انسٹال کریں';
  static const billPhoto = 'بل کی تصویر';

  static const complaintTitle = 'شکایت کا پیغام';
  static const copy = 'کاپی';
  static const share = 'شیئر';
  static const call118 = '118 پر کال';
  static const copied = 'کاپی ہو گیا';

  static const history = 'پچھلے بل';
  static const deleteBillQ = 'یہ بل مٹا دیں؟';
  static const deleteConnectionQ = 'یہ کنکشن اور اس کے سارے بل مٹا دیں؟';
  static const delete = 'مٹا دیں';
  static const no = 'نہیں';
  static const longPressHint = 'بل مٹانے کے لیے اسے دبا کر رکھیں';

  static const voiceSpeed = 'آواز کی رفتار';
  static const slow = 'آہستہ';
  static const normal = 'عام';
  static const textSize = 'لکھائی کا سائز';
  static const large = 'بڑا';
  static const clearAll = 'سارا ڈیٹا مٹا دیں';
  static const clearAllQ = 'سارے کنکشن اور بل مٹا دیں؟ یہ واپس نہیں آئیں گے۔';
}
