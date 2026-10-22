import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/i18n/$lang.json').readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String text) => RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final en = _load('en');
  final ur = _load('ur');

  test('English and Urdu have the same keys and placeholders', () {
    for (final section in ['ui', 'templates', 'errors']) {
      final a = en[section] as Map<String, dynamic>;
      final b = ur[section] as Map<String, dynamic>;
      expect(b.keys.toSet(), a.keys.toSet(), reason: section);
      for (final key in a.keys) {
        expect(_placeholders(b[key] as String), _placeholders(a[key] as String), reason: '$section.$key');
      }
    }
    expect((ur['months'] as List).length, 12);
    expect((en['months'] as List).length, 12);
    expect(
      (ur['glossary'] as List).map((e) => e['code']).toList(),
      (en['glossary'] as List).map((e) => e['code']).toList(),
    );
  });

  test('every UI key used in the code exists', () {
    final ui = (en['ui'] as Map<String, dynamic>).keys.toSet();
    final used = <String>{};
    final call = RegExp(r"""\.t\(\s*'([a-z0-9_]+)'""");
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      used.addAll(call.allMatches(file.readAsStringSync()).map((m) => m.group(1)!));
    }
    // Keys built dynamically.
    used.removeWhere((k) => k.startsWith('verdict_'));
    expect(used.difference(ui), isEmpty);
    expect(used, isNotEmpty);
  });

  test('preset nickname keys exist', () {
    for (final key in ['preset_home', 'preset_shop', 'preset_parents', 'verdict_normal_label', 'verdict_check_label', 'verdict_wrong_label']) {
      expect((en['ui'] as Map).containsKey(key), isTrue, reason: key);
    }
  });
}
