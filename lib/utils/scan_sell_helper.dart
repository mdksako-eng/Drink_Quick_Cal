// utils/scan_sell_helper.dart
// "One unit, or the whole pack?" — the two ways this business sells, straight from a scan.
//
// A scanned drink goes into a sale, and the same drink is sold BOTH ways: one bottle
// over the counter, and a crate of them to a bar. The pack size is a property of the
// DRINK (`unitsPerPack`, entered once in the catalogue), so the scanner reads it
// instead of offering a guessed ladder (1/6/12/24/48) that was wrong for every drink
// whose case is not 24 — a 12-bottle crate was being offered "24", and a drink sold by
// the glass was offered "48".
//
// Pure, so what a scan offers is unit tested rather than living inside a bottom sheet.
import '../models/drink_model.dart';

/// One quick way to sell the scanned drink.
class ScanSellOption {
  const ScanSellOption({required this.quantity, required this.isPack});

  final int quantity;

  /// True for the drink's own case/pack size — the batch sale.
  final bool isPack;

  @override
  bool operator ==(Object other) =>
      other is ScanSellOption &&
      other.quantity == quantity &&
      other.isPack == isPack;

  @override
  int get hashCode => Object.hash(quantity, isPack);

  @override
  String toString() =>
      'ScanSellOption($quantity${isPack ? ', pack' : ', single'})';
}

class ScanSellHelper {
  ScanSellHelper._();

  /// The quick choices for a scanned drink: a single unit, and the whole pack when the
  /// catalogue says the pack is more than one.
  ///
  /// Always at least the single unit. A drink whose pack size is 1 (a glass, a piece)
  /// offers only that, and a pack size of 1 can never produce a second, identical chip.
  static List<ScanSellOption> options(Drink drink) {
    final pack = packSize(drink);
    return <ScanSellOption>[
      const ScanSellOption(quantity: 1, isPack: false),
      if (pack > 1) ScanSellOption(quantity: pack, isPack: true),
    ];
  }

  /// The drink's pack size, never below 1 — a bad catalogue value must not offer "0".
  static int packSize(Drink drink) {
    final units = drink.unitsPerPack;
    return units > 1 ? units : 1;
  }

  /// Is this quantity a whole number of packs (the batch sale, however it was typed)?
  static bool isWholePack(Drink drink, int quantity) {
    final pack = packSize(drink);
    return pack > 1 && quantity > 0 && quantity % pack == 0;
  }

  /// Whether the shelf holds fewer units than [quantity].
  ///
  /// A NOTE, never a block: the shelf can be short and the sale still stands, and a shop
  /// that does not track stock at all has no shelf figure to compare with. The server is
  /// the only authority on stock.
  static bool exceedsShelf({required int quantity, required int shelf}) =>
      shelf > 0 && quantity > shelf;
}
