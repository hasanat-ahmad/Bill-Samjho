import 'package:bill_samjho/services/urdu_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numbers in Urdu words, Pakistani system', () {
    expect(UrduNumbers.words(0), 'صفر');
    expect(UrduNumbers.words(15), 'پندرہ');
    expect(UrduNumbers.words(67), 'سڑسٹھ');
    expect(UrduNumbers.words(100), 'ایک سو');
    expect(UrduNumbers.words(186), 'ایک سو چھیاسی');
    expect(UrduNumbers.words(4367), 'چار ہزار تین سو سڑسٹھ');
    expect(UrduNumbers.words(7233), 'سات ہزار دو سو تینتیس');
    expect(UrduNumbers.words(10107), 'دس ہزار ایک سو سات');
    expect(UrduNumbers.words(2026), 'دو ہزار چھبیس');
    expect(UrduNumbers.words(125000), 'ایک لاکھ پچیس ہزار');
    expect(UrduNumbers.words(12345678), 'ایک کروڑ تیئس لاکھ پینتالیس ہزار چھ سو اٹھہتر');
  });

  test('numbers inside text: amounts with commas, years, decimals, codes', () {
    expect(UrduNumbers.inText('آپ کا بل 4,367 روپے ہے'), 'آپ کا بل چار ہزار تین سو سڑسٹھ روپے ہے');
    expect(UrduNumbers.inText('14 اکتوبر 2026'), 'چودہ اکتوبر دو ہزار چھبیس');
    expect(UrduNumbers.inText('152.50'), 'ایک سو باون اعشاریہ پانچ صفر');
    expect(UrduNumbers.inText('0947000'), 'صفر نو چار سات صفر صفر صفر');
    // A comma that only ends a clause is not part of the number.
    expect(UrduNumbers.inText('186، 200'), 'ایک سو چھیاسی، دو سو');
  });
}
