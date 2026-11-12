// test/scan_sell_test.dart
// "One unit, or the whole pack?" — what a scan offers to sell.
//
// The bug this pins: the sell sheet offered a guessed ladder (1/6/12/24/48), so a
// 12-bottle crate was offered "24" and a drink sold by the glass was offered "48".
// The pack size is the DRINK's own property (`unitsPerPack`).
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_calculator_fixed/models/drink_model.dart';
import 'package:drinks_calculator_fixed/utils/scan_sell_helper.dart';

Drink drink({int unitsPerPack = 1}) => Drink(
      id: 'd1',
      name: 'Beer',
      price: 1000,
      imageUrl: '',
      unitsPerPack: unitsPerPack,
    );

void main() {
  group('options', () {
    test('a pack drink offers the single unit AND the whole pack', () {
      expect(
        ScanSellHelper.options(drink(unitsPerPack: 24)),
        const [
          ScanSellOption(quantity: 1, isPack: false),
          ScanSellOption(quantity: 24, isPack: true),
        ],
      );
    });

    test('the pack size is the drink own, not a guessed one', () {
      final twelve = ScanSellHelper.options(drink(unitsPerPack: 12));
      expect(twelve.map((option) => option.quantity).toList(), [1, 12]);
      // "24" must not appear for a 12-bottle crate.
      expect(twelve.any((option) => option.quantity == 24), isFalse);
    });

    test('a drink sold by the unit offers only itself', () {
      expect(
        ScanSellHelper.options(drink()),
        const [ScanSellOption(quantity: 1, isPack: false)],
      );
    });

    test('a broken pack size never offers 0, nor a duplicate chip', () {
      expect(ScanSellHelper.options(drink(unitsPerPack: 0)).length, 1);
      expect(ScanSellHelper.options(drink(unitsPerPack: -5)).length, 1);
      expect(ScanSellHelper.options(drink(unitsPerPack: 1)).length, 1);
    });
  });

  group('packSize', () {
    test('never below one', () {
      expect(ScanSellHelper.packSize(drink(unitsPerPack: 0)), 1);
      expect(ScanSellHelper.packSize(drink(unitsPerPack: 1)), 1);
      expect(ScanSellHelper.packSize(drink(unitsPerPack: 6)), 6);
    });
  });

  group('isWholePack', () {
    test('recognises a batch however it was typed', () {
      final crate = drink(unitsPerPack: 24);
      expect(ScanSellHelper.isWholePack(crate, 24), isTrue);
      expect(ScanSellHelper.isWholePack(crate, 48), isTrue);
      expect(ScanSellHelper.isWholePack(crate, 25), isFalse);
      expect(ScanSellHelper.isWholePack(crate, 0), isFalse);
    });

    test('a single-unit drink is never "a pack"', () {
      expect(ScanSellHelper.isWholePack(drink(), 1), isFalse);
      expect(ScanSellHelper.isWholePack(drink(), 5), isFalse);
    });
  });

  group('exceedsShelf', () {
    test('a short shelf is flagged', () {
      expect(ScanSellHelper.exceedsShelf(quantity: 24, shelf: 6), isTrue);
      expect(ScanSellHelper.exceedsShelf(quantity: 6, shelf: 6), isFalse);
    });

    test('no shelf figure is not a shortfall', () {
      // A shop that does not track stock (or an item with no inventory row) must not be
      // locked to a single unit — the server is the only authority on stock.
      expect(ScanSellHelper.exceedsShelf(quantity: 24, shelf: 0), isFalse);
      expect(ScanSellHelper.exceedsShelf(quantity: 24, shelf: -3), isFalse);
    });
  });
}
