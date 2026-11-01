// utils/text_search.dart
// One way to search a list by typing.
//
// WHY THIS EXISTS. Several screens now let an operator pick something out of a list
// they cannot realistically scroll: a customer account at the till, a customer
// holding crates, a drink on a purchase order. The rule is the same in all of them,
// and it is the rule that makes a search feel broken when it is missing:
//   * case does not matter;
//   * accents do not matter — "emile" must find "Émile", because this is a
//     French-speaking market and nobody types the accent into a search box;
//   * a phone number or a barcode also matches on its DIGITS, so "6 77 12 34 56"
//     finds "+237 677123456" and a barcode is not defeated by its own formatting.
//
// Pure functions, so the rule is unit tested (test/customer_ledger_test.dart)
// without pumping a widget.

class TextSearch {
  TextSearch._();

  /// Common accented letters folded to their plain form, so "Émile" and "emile"
  /// are the same string to a search.
  static const Map<String, String> _foldedLetters = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };

  /// Lower-cased, trimmed and stripped of accents.
  static String fold(String? text) {
    final lower = (text ?? '').trim().toLowerCase();
    if (lower.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(_foldedLetters[character] ?? character);
    }
    return buffer.toString();
  }

  /// Digits only: "+237 677-123-456" → "237677123456".
  static String digitsOnly(String? text) =>
      (text ?? '').replaceAll(RegExp(r'\D'), '');

  /// True when [query] matches any of [fields].
  ///
  /// An empty query matches everything — that is what a cleared search box means.
  static bool textMatches(String query, Iterable<String?> fields) {
    final wanted = fold(query);
    if (wanted.isEmpty) return true;
    final digits = digitsOnly(query);

    for (final field in fields) {
      final value = fold(field);
      if (value.isEmpty) continue;
      if (value.contains(wanted)) return true;
      if (digits.isNotEmpty && digitsOnly(field).contains(digits)) return true;
    }
    return false;
  }
}
