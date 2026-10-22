import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App languages. English is the default; Urdu is right-to-left.
enum AppLanguage {
  en,
  ur;

  bool get isRtl => this == ur;

  Locale get locale => Locale(name, 'PK');

  /// Text-to-speech voices to try, in order.
  List<String> get ttsLocales => switch (this) {
        en => const ['en-IN', 'en-GB', 'en-US'],
        ur => const ['ur-PK', 'ur-IN'],
      };

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => en);
}

/// All user-facing text for one language, from `assets/i18n/LANG.json`.
class AppStrings {
  AppStrings(this.language, this._json);

  final AppLanguage language;
  final Map<String, dynamic> _json;

  /// UI label [key], with `{placeholders}` replaced from [values].
  String t(String key, [Map<String, String> values = const {}]) => _fill(_section('ui')[key], key, values);

  /// Explanation template [key] (SDA §10.3).
  String template(String key, [Map<String, String> values = const {}]) =>
      _fill(_section('templates')[key], key, values);

  List<String> get months => List<String>.from(_json['months'] as List);

  String error(String code) {
    final errors = _section('errors');
    return (errors[code] ?? errors['unknown']) as String;
  }

  List<GlossaryItem> get glossary => [
        for (final e in _json['glossary'] as List)
          GlossaryItem(
            code: e['code'] as String,
            icon: e['icon'] as String,
            title: e['title'] as String,
            meaning: e['meaning'] as String,
          ),
      ];

  Map<String, dynamic> _section(String name) => _json[name] as Map<String, dynamic>;

  static String _fill(Object? raw, String key, Map<String, String> values) {
    // A missing key shows itself instead of crashing; tests catch it.
    var text = raw as String? ?? key;
    values.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }
}

class GlossaryItem {
  const GlossaryItem({required this.code, required this.icon, required this.title, required this.meaning});

  final String code; // as printed on the bill, e.g. "FPA"
  final String icon;
  final String title;
  final String meaning;
}

extension StringsContext on BuildContext {
  /// Current language strings; rebuilds the widget when the language changes.
  /// Use `context.read<AppStrings>()` inside callbacks.
  AppStrings get s => watch<AppStrings>();
}
