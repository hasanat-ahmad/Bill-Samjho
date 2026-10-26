import '../core/i18n.dart';
import 'urdu_numbers.dart';

/// Rewrites text the way a native speaker would say it, before it is
/// spoken: the screen keeps "Rs 7,233" and "FPA", the voice hears
/// "7,233 rupees" and "ایف پی اے". Text-to-speech voices otherwise spell out
/// symbols and read Latin letters inside Urdu badly.
class SpeechText {
  static String prepare(String text, AppLanguage language) {
    var t = text;
    // A helpline number is said digit by digit, not "one hundred eighteen".
    t = t.replaceAllMapped(_helpline, (m) => language == AppLanguage.ur ? 'ایک ایک آٹھ' : 'one one eight');
    t = t.replaceAllMapped(_website, (m) => _spellSite(m[0]!, language));
    if (language == AppLanguage.ur) {
      // "186 / 200" → "200 میں سے 186"
      t = t.replaceAllMapped(_outOf, (m) => '${m[2]} میں سے ${m[1]}');
      t = t.replaceAllMapped(_rupeesBefore, (m) => '${m[1]} روپے');
      for (final e in _urduWords.entries) {
        t = t.replaceAll(RegExp('\\b${RegExp.escape(e.key)}\\b'), e.value);
      }
      // Last: the numbers themselves, as words the voice cannot misread.
      t = UrduNumbers.inText(t);
    } else {
      t = t.replaceAllMapped(_outOf, (m) => '${m[1]} out of ${m[2]}');
      t = t.replaceAllMapped(_rupeesBefore, (m) => '${m[1]} rupees');
      for (final e in _englishWords.entries) {
        t = t.replaceAll(RegExp('\\b${RegExp.escape(e.key)}\\b'), e.value);
      }
    }
    // Symbols a voice reads aloud or stumbles on.
    return t.replaceAll('·', ',').replaceAll('–', ' to ').replaceAll(RegExp(r'[*_#•]'), ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  static final _helpline = RegExp(r'(?<![\d,])118(?![\d,])');
  static final _outOf = RegExp('($_number)\\s*/\\s*($_number)');
  // "Rs 7,233", "Rs. 7,233.50", "Rs7233"
  static final _rupeesBefore = RegExp('\\bRs\\.?\\s?($_number)');

  /// 7,233 or 7233 or 152.50, without a comma that only ends the clause.
  static const _number = r'\d+(?:,\d{3})*(?:\.\d+)?';
  static final _website = RegExp(r'\b[a-z0-9-]+(?:\.[a-z]{2,}){1,3}\b');

  static String _spellSite(String site, AppLanguage language) {
    final ur = language == AppLanguage.ur;
    return site.split('.').map((part) => switch (part) {
          'org' => ur ? 'او آر جی' : 'org',
          'pk' => ur ? 'پی کے' : 'P K',
          'com' => ur ? 'کام' : 'com',
          'nepra' => ur ? 'نیپرا' : 'nepra',
          _ => part,
        }).join(ur ? ' ڈاٹ ' : ' dot ');
  }

  /// English: units and codes a voice would mispronounce.
  static const _englishWords = {
    'kW': 'kilowatt',
    'kWh': 'kilowatt hour',
    'QTR': 'quarterly',
    'L.P.': 'late payment',
  };

  /// Latin abbreviations and names inside Urdu, written as an Urdu speaker
  /// says them.
  static const _urduWords = {
    'FPA': 'ایف پی اے',
    'QTR': 'کیو ٹی آر',
    'GST': 'جی ایس ٹی',
    'PTV': 'پی ٹی وی',
    'ED': 'ای ڈی',
    'NEPRA': 'نیپرا',
    'PITC': 'پی آئی ٹی سی',
    'WAPDA': 'واپڈا',
    'DISCO': 'ڈسکو',
    'AI': 'اے آئی',
    'Gemini': 'جیمنائی',
    'Google': 'گوگل',
    'Asaan Approach': 'آسان اپروچ',
    'K-Electric': 'کے الیکٹرک',
    'LESCO': 'لیسکو',
    'PESCO': 'پیسکو',
    'IESCO': 'آئیسکو',
    'GEPCO': 'گیپکو',
    'FESCO': 'فیسکو',
    'MEPCO': 'میپکو',
    'HESCO': 'حیسکو',
    'SEPCO': 'سیپکو',
    'QESCO': 'کیسکو',
    'TESCO': 'ٹیسکو',
    'HAZECO': 'ہزیکو',
    'kW': 'کلو واٹ',
    'Rs': 'روپے',
    'Unprotected': 'اَن پروٹیکٹڈ',
    'Protected': 'پروٹیکٹڈ',
    'Speech Services': 'اسپیچ سروسز',
    'Search': 'سرچ',
    'Fixed': 'فکسڈ',
    'Arrears': 'بقایا',
    'Surcharge': 'سرچارج',
    'Fee': 'فیس',
  };
}
