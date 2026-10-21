/// Urdu templates, month names, error messages and glossary
/// loaded from assets/urdu_strings.json.
class UrduStrings {
  UrduStrings(this._json);

  final Map<String, dynamic> _json;

  /// Returns template [key] with each `{placeholder}` replaced from [values].
  String fill(String key, [Map<String, String> values = const {}]) {
    var text = _json[key] as String? ?? '';
    values.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }

  List<String> get months => List<String>.from(_json['months'] as List);

  String error(String code) {
    final errors = _json['errors'] as Map<String, dynamic>;
    return (errors[code] ?? errors['unknown']) as String;
  }

  List<GlossaryItem> get glossary => (_json['glossary'] as List)
      .map((e) => GlossaryItem(
            code: e['code'] as String,
            title: e['title'] as String,
            meaning: e['meaning'] as String,
          ))
      .toList();
}

class GlossaryItem {
  const GlossaryItem({required this.code, required this.title, required this.meaning});

  final String code; // as printed on the bill, e.g. "FPA"
  final String title;
  final String meaning;
}
