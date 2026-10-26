/// Numbers as Urdu words, in the Pakistani system (ہزار، لاکھ، کروڑ), so a
/// voice never has to guess: "4,367" is read by Urdu voices as 4 rupees and
/// 367 paisa, but "چار ہزار تین سو سڑسٹھ" can only be said one way.
class UrduNumbers {
  /// 0–99: every one is its own word in Urdu.
  static const _under100 = [
    'صفر', 'ایک', 'دو', 'تین', 'چار', 'پانچ', 'چھ', 'سات', 'آٹھ', 'نو', //
    'دس', 'گیارہ', 'بارہ', 'تیرہ', 'چودہ', 'پندرہ', 'سولہ', 'سترہ', 'اٹھارہ', 'انیس',
    'بیس', 'اکیس', 'بائیس', 'تیئس', 'چوبیس', 'پچیس', 'چھبیس', 'ستائیس', 'اٹھائیس', 'انتیس',
    'تیس', 'اکتیس', 'بتیس', 'تینتیس', 'چونتیس', 'پینتیس', 'چھتیس', 'سینتیس', 'اڑتیس', 'انتالیس',
    'چالیس', 'اکتالیس', 'بیالیس', 'تینتالیس', 'چوالیس', 'پینتالیس', 'چھیالیس', 'سینتالیس', 'اڑتالیس', 'انچاس',
    'پچاس', 'اکیاون', 'باون', 'ترپن', 'چون', 'پچپن', 'چھپن', 'ستاون', 'اٹھاون', 'انسٹھ',
    'ساٹھ', 'اکسٹھ', 'باسٹھ', 'تریسٹھ', 'چونسٹھ', 'پینسٹھ', 'چھیاسٹھ', 'سڑسٹھ', 'اڑسٹھ', 'انہتر',
    'ستر', 'اکہتر', 'بہتر', 'تہتر', 'چوہتر', 'پچھتر', 'چھہتر', 'ستتر', 'اٹھہتر', 'اناسی',
    'اسی', 'اکاسی', 'بیاسی', 'تراسی', 'چوراسی', 'پچاسی', 'چھیاسی', 'ستاسی', 'اٹھاسی', 'نواسی',
    'نوے', 'اکانوے', 'بانوے', 'ترانوے', 'چورانوے', 'پچانوے', 'چھیانوے', 'ستانوے', 'اٹھانوے', 'ننانوے',
  ];

  /// [n] in words, for 0 up to 99 crore.
  static String words(int n) {
    if (n < 0) return 'منفی ${words(-n)}';
    if (n < 100) return _under100[n];
    final parts = <String>[];
    void add(int count, String unit) {
      if (count > 0) parts.add('${words(count)} $unit');
    }

    add(n ~/ 10000000, 'کروڑ');
    add(n ~/ 100000 % 100, 'لاکھ');
    add(n ~/ 1000 % 100, 'ہزار');
    add(n ~/ 100 % 10, 'سو');
    if (n % 100 > 0) parts.add(_under100[n % 100]);
    return parts.join(' ');
  }

  /// Every number in [text] in words: "4,367" and "2026" become words; a
  /// decimal is said with اعشاریہ and its digits; a long code (a reference
  /// number, a number starting with 0) is said digit by digit.
  static String inText(String text) => text.replaceAllMapped(_number, (m) {
        final raw = m[0]!;
        final [whole, ...rest] = raw.split('.');
        final digits = whole.replaceAll(',', '');
        if (digits.length > 9 || (digits.length > 1 && digits.startsWith('0'))) {
          return digits.split('').map((d) => _under100[int.parse(d)]).join(' ');
        }
        final said = words(int.parse(digits));
        if (rest.isEmpty) return said;
        return '$said اعشاریہ ${rest.first.split('').map((d) => _under100[int.parse(d)]).join(' ')}';
      });

  // 4,367 · 1,25,000 · 2026 · 152.50 (a comma only between digit groups).
  static final _number = RegExp(r'\d+(?:,\d{2,3})*(?:\.\d+)?');
}
