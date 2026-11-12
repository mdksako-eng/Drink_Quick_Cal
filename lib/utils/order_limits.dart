// utils/order_limits.dart
// How many units ONE line of a sale may carry — one rule, in one place.
//
// THE BUG THIS EXISTS FOR: the till capped a quantity at 99 in four separate places (the
// typed field, its helper text, and both + steppers) while the dictates capped it at 99
// twice more (voice command, AI parser) — and the scanner's send-to-calculator allowed
// 999. Three different answers to the same question. 99 is a retail number: a crate sale
// to a bar is 24, and a wholesale drop is hundreds, so a cashier who typed 120 silently
// got 99, and dictating "order 120 crates" recorded 99.
//
// WHY NOT UNLIMITED: the cart stores one entry per UNIT (`Order.items` holds the drink
// once per unit — that is what the invoice, the stock ledger and the purchase history all
// read), so the request body grows with the quantity. 999 keeps one line near 200 KB,
// comfortably inside the backend's 1 MB JSON limit (server.js). Selling more than that in
// ONE line needs the payload to carry a quantity instead of one entry per unit — a real
// change, not a bigger clamp, and it is deliberately not pretended here.
class OrderLimits {
  OrderLimits._();

  /// The most units a single line of a sale may carry.
  static const int maxQuantity = 999;

  /// One quantity brought into range: unreadable or below 1 becomes 1, above the
  /// ceiling becomes the ceiling. Never zero and never negative — a sale line always
  /// sells something.
  static int clampQuantity(Object? value) {
    final parsed = value is int ? value : int.tryParse('${value ?? ''}');
    if (parsed == null || parsed < 1) return 1;
    return parsed > maxQuantity ? maxQuantity : parsed;
  }
}
