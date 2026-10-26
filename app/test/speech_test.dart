import 'package:bill_samjho/core/i18n.dart';
import 'package:bill_samjho/services/speech_text.dart';
import 'package:bill_samjho/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String en(String t) => SpeechText.prepare(t, AppLanguage.en);
  String ur(String t) => SpeechText.prepare(t, AppLanguage.ur);

  group('English is said the way a person says it', () {
    test('rupee amounts', () {
      expect(en('Your bill is Rs 7,233, due by 15 October 2026.'), 'Your bill is 7,233 rupees, due by 15 October 2026.');
      expect(en('That is roughly Rs 5,872 to Rs 10,107.'), 'That is roughly 5,872 rupees to 10,107 rupees.');
      expect(en('Rs. 152.50'), '152.50 rupees');
    });

    test('limits, the helpline and a website', () {
      expect(en('186 / 200 units'), '186 out of 200 units');
      expect(en('Send it or call 118.'), 'Send it or call one one eight.');
      expect(en('complain to NEPRA on nepra.org.pk'), 'complain to NEPRA on nepra dot org dot P K');
    });

    test('numbers that only contain 118 are left alone', () {
      expect(en('Rs 1,180 and 2118 units'), '1,180 rupees and 2118 units');
    });

    test('markdown and symbols are not read out', () {
      expect(en('• **Fixed charges** · Rs 600'), 'Fixed charges , 600 rupees');
    });
  });

  group('Urdu', () {
    test('Latin abbreviations and company names in Urdu', () {
      expect(ur('بل میں FPA اور GST شامل ہے۔'), 'بل میں ایف پی اے اور جی ایس ٹی شامل ہے۔');
      expect(ur('LESCO ستمبر 2026 کا بل'), 'لیسکو ستمبر دو ہزار چھبیس کا بل');
      expect(ur('(FPA) فیول پرائس ایڈجسٹمنٹ'), '(ایف پی اے) فیول پرائس ایڈجسٹمنٹ');
      expect(ur('آپ غیر محفوظ صارف (Unprotected) ہیں'), 'آپ غیر محفوظ صارف (اَن پروٹیکٹڈ) ہیں');
      expect(ur('Google Speech Services انسٹال کریں'), 'گوگل اسپیچ سروسز انسٹال کریں');
    });

    test('the bill amount is said in thousands, never as rupees and paisa', () {
      expect(ur('آپ کا بل 4,367 روپے ہے، جو 14 اکتوبر 2026 تک جمع کروانا ہے۔'),
          'آپ کا بل چار ہزار تین سو سڑسٹھ روپے ہے، جو چودہ اکتوبر دو ہزار چھبیس تک جمع کروانا ہے۔');
    });

    test('limit, helpline and rupees in Urdu word order', () {
      expect(ur('186 / 200 یونٹ'), 'دو سو میں سے ایک سو چھیاسی یونٹ');
      expect(ur('اسے بھیجیں یا 118 پر کال کریں۔'), 'اسے بھیجیں یا ایک ایک آٹھ پر کال کریں۔');
      expect(ur('Rs 7,233'), 'سات ہزار دو سو تینتیس روپے');
      expect(ur('nepra.org.pk'), 'نیپرا ڈاٹ او آر جی ڈاٹ پی کے');
    });
  });

  group('voice choice', () {
    final voices = [
      {'name': 'ur-pk-x-cfn-network', 'locale': 'ur-PK', 'network': '1'},
      {'name': 'ur-in-x-urc-local', 'locale': 'ur-IN', 'network': '0'},
      {'name': 'ur-PK-language', 'locale': 'ur-PK', 'network': '0'},
      {'name': 'ur-pk-x-cfn-local', 'locale': 'ur-PK', 'network': '0'},
      {'name': 'ur-in-x-urb-network', 'locale': 'ur-IN', 'network': '1'},
      {'name': 'ur-in-x-urb-local', 'locale': 'ur-IN', 'network': '0'},
    ];

    test('offline voices only, Pakistani Urdu first, always in the same order', () {
      final names = TtsService.offlineVoices(voices, ['ur-pk', 'ur-in']).map((v) => v['name']).toList();
      expect(names, ['ur-pk-x-cfn-local', 'ur-in-x-urb-local', 'ur-in-x-urc-local']);
    });
  });
}
