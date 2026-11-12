// test/order_limits_test.dart
// The quantity a wholesale shop is allowed to type, dictate or scan.
//
// The bug this pins: 99 in four calculator places and two dictates, 999 in the scanner.
// A crate sale is 24 and a wholesale drop is hundreds, so 99 refused the ordinary case.
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_calculator_fixed/utils/order_limits.dart';

void main() {
  group('clampQuantity', () {
    test('keeps an ordinary wholesale quantity exactly as typed', () {
      expect(OrderLimits.clampQuantity(24), 24); // a crate
      expect(OrderLimits.clampQuantity(120), 120); // no longer silently 99
      expect(OrderLimits.clampQuantity(999), 999);
    });

    test('never goes above the ceiling', () {
      expect(OrderLimits.clampQuantity(1000), OrderLimits.maxQuantity);
      expect(OrderLimits.clampQuantity(999999), OrderLimits.maxQuantity);
    });

    test('never goes below one', () {
      expect(OrderLimits.clampQuantity(0), 1);
      expect(OrderLimits.clampQuantity(-5), 1);
    });

    test('an unreadable value becomes one rather than zero', () {
      expect(OrderLimits.clampQuantity(null), 1);
      expect(OrderLimits.clampQuantity(''), 1);
      expect(OrderLimits.clampQuantity('abc'), 1);
    });

    test('reads a string, because the fields and the dictates hand over text', () {
      expect(OrderLimits.clampQuantity('48'), 48);
      expect(OrderLimits.clampQuantity(' 12 '), 12);
    });

    test('the ceiling leaves room inside the backend JSON limit', () {
      // 999 units is one entry per unit in the order payload; the old global 12 MB was
      // cut to 1 MB (server.js), so this ceiling has to stay well under it.
      expect(OrderLimits.maxQuantity, lessThanOrEqualTo(1000));
    });
  });
}
