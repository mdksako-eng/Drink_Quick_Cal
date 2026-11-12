// test/refund_lane_test.dart
// A refund must follow the money's ORIGINAL path: a sale collected through
// CamerPay is refunded at CamerPay (and tied to its provider reference), a sale
// paid in cash is refunded out of the drawer and has no provider line at all.
//
// These rules mirror backend/utils/refundRecord.js — if one changes, both must.
import 'package:flutter_test/flutter_test.dart';
import 'package:drinks_calculator_fixed/utils/refund_lane_helper.dart';

void main() {
  group('normalize', () {
    test('reads every spelling of a rail as one word', () {
      expect(RefundLaneHelper.normalize('MTN MoMo'), 'mtn');
      expect(RefundLaneHelper.normalize('mtn_momo'), 'mtn');
      expect(RefundLaneHelper.normalize('mtnMobileMoney'), 'mtn');
      expect(RefundLaneHelper.normalize('orangeMoney'), 'orange');
      expect(RefundLaneHelper.normalize('visa'), 'card');
      expect(RefundLaneHelper.normalize('CASH'), 'cash');
    });

    test('nothing to read stays nothing', () {
      expect(RefundLaneHelper.normalize(null), '');
      expect(RefundLaneHelper.normalize('   '), '');
    });
  });

  group('lane', () {
    test('cash is the drawer, everything else is the provider', () {
      expect(RefundLaneHelper.lane('cash'), RefundLane.cash);
      expect(RefundLaneHelper.lane('CASH'), RefundLane.cash);
      expect(RefundLaneHelper.lane('mtnMobileMoney'), RefundLane.provider);
      expect(RefundLaneHelper.lane('orangeMoney'), RefundLane.provider);
      expect(RefundLaneHelper.lane('card'), RefundLane.provider);
    });

    test('an unreadable method keeps the provider assumption, never cash', () {
      // Filing a CamerPay collection as cash would hide money the drawer was never
      // responsible for — the backend defaults the same way.
      expect(RefundLaneHelper.lane(null), RefundLane.provider);
      expect(RefundLaneHelper.lane(''), RefundLane.provider);
      expect(RefundLaneHelper.isCash(''), isFalse);
      expect(RefundLaneHelper.isCash('cash'), isTrue);
    });
  });

  group('what the dialogs show', () {
    test('the title and the hint follow the lane', () {
      expect(RefundLaneHelper.titleKey('cash'), 'refundLaneCashTitle');
      expect(RefundLaneHelper.titleKey('mtn'), 'refundLaneProviderTitle');
      expect(RefundLaneHelper.hintKey('cash'), 'refundLaneCashHint');
      expect(RefundLaneHelper.hintKey('card'), 'refundLaneProviderHint');
      expect(RefundLaneHelper.returnLabelKey('cash'), 'returnLaneCash');
      expect(RefundLaneHelper.returnLabelKey('orange'), 'returnLaneProvider');
    });

    test('a provider reference is only asked for on the CamerPay lane', () {
      expect(RefundLaneHelper.needsProviderReference('cash'), isFalse);
      expect(RefundLaneHelper.needsProviderReference('mtn'), isTrue);
      expect(RefundLaneHelper.needsProviderReference(''), isTrue);
    });

    test('the method about to be stored is named in plain words', () {
      expect(RefundLaneHelper.methodLabel('cash'), 'Cash');
      expect(RefundLaneHelper.methodLabel('mtnMobileMoney'), 'MTN MoMo');
      expect(RefundLaneHelper.methodLabel('orangeMoney'), 'Orange Money');
      expect(RefundLaneHelper.methodLabel('card'), 'Card');
    });
  });
}
