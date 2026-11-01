// test/text_search_test.dart
// The rule behind every search box in the app: a customer at the till, a customer
// holding crates, a drink on a purchase order. It is shared (utils/text_search.dart)
// so that one search never behaves differently from another.
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_calculator_fixed/utils/text_search.dart';

void main() {
  group('folding text', () {
    test('case and accents are ignored, and the text is trimmed', () {
      expect(TextSearch.fold('  Émile  '), 'emile');
      expect(TextSearch.fold('NKOLO'), 'nkolo');
      expect(TextSearch.fold('François'), 'francois');
      expect(TextSearch.fold('CEUR'), 'ceur');
      expect(TextSearch.fold('Œuvre'), 'oeuvre');
      expect(TextSearch.fold(null), '');
      expect(TextSearch.fold('   '), '');
    });

    test('digits only, so formatting never hides a number', () {
      expect(TextSearch.digitsOnly('+237 677-123-456'), '237677123456');
      expect(TextSearch.digitsOnly('C-0007'), '0007');
      expect(TextSearch.digitsOnly('emile'), '');
      expect(TextSearch.digitsOnly(null), '');
    });
  });

  group('matching a query', () {
    test('an empty query matches everything — a cleared box filters nothing', () {
      expect(TextSearch.textMatches('', ['anything']), isTrue);
      expect(TextSearch.textMatches('   ', ['anything']), isTrue);
    });

    test('a name matches with or without its accent, in any case', () {
      expect(TextSearch.textMatches('emile', ['Émile Nkolo']), isTrue);
      expect(TextSearch.textMatches('ÉMILE', ['Émile Nkolo']), isTrue);
      expect(TextSearch.textMatches('kolo', ['Émile Nkolo']), isTrue);
      expect(TextSearch.textMatches('awa', ['Émile Nkolo']), isFalse);
    });

    test('a number matches on its digits, whatever the punctuation', () {
      expect(TextSearch.textMatches('677 12 34 56', ['+237 677123456']), isTrue);
      expect(TextSearch.textMatches('677123456', ['+237 677 12 34 56']), isTrue);
      // A scanned barcode is matched the same way.
      expect(TextSearch.textMatches('37001234', ['', '3 700 1234']), isTrue);
    });

    test('any field can match, and empty fields are skipped', () {
      expect(TextSearch.textMatches('c-0007', ['Émile', 'C-0007']), isTrue);
      expect(TextSearch.textMatches('mokolo', ['', '  ', 'Marché Mokolo']), isTrue);
      expect(TextSearch.textMatches('zzz', ['', null, 'Marché Mokolo']), isFalse);
    });

    test('a query of punctuation alone matches nothing', () {
      expect(TextSearch.textMatches('---', ['Émile', 'C-0007']), isFalse);
    });
  });
}
