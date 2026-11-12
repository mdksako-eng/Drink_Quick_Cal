// utils/refund_lane_helper.dart
// "Where does this refund go back?" — one rule, shared by the refund dialog and
// the return dialog.
//
// It deliberately mirrors the backend's utils/refundRecord.js, so the screen can
// never disagree with the row the server stores.
//
// The money must follow the path it arrived by: a sale collected through CamerPay
// (mtn / orange / card) is refunded at CamerPay and tied to its provider
// reference, while a sale paid in cash is refunded out of the drawer and has no
// provider line at all. Filing every refund as cash — or every refund as CamerPay —
// makes the books wrong at the till.
//
// Pure, so the rule is unit tested instead of living inside a dialog.

/// Which way the money goes back.
enum RefundLane { cash, provider }

class RefundLaneHelper {
  RefundLaneHelper._();

  /// One alias table, in one place. The app sends the till's `PaymentMethod.name`
  /// ('cash', 'mtnMobileMoney', 'orangeMoney', 'card'); the backend may hand back a
  /// CamerPay rail ('mtn', 'orange', 'card') or nothing at all.
  static const Map<String, String> _aliases = {
    'cash': 'cash',
    'mtn': 'mtn',
    'momo': 'mtn',
    'mtnmobilemoney': 'mtn',
    'mtnmomo': 'mtn',
    'orange': 'orange',
    'orangemoney': 'orange',
    'card': 'card',
    'visa': 'card',
    'stripe': 'card',
    'paypal': 'paypal',
  };

  /// One spelling of a payment method, or '' when there is nothing to read.
  /// Case, spaces, dashes and underscores are ignored, so 'MTN MoMo' and
  /// 'mtn_momo' read as the same rail.
  static String normalize(String? method) {
    final raw = (method ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';
    final key = raw.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return _aliases[key] ?? raw;
  }

  /// A sale paid in cash — the only money a drawer is accountable for.
  static bool isCash(String? method) => normalize(method) == 'cash';

  /// Which lane the refund travels.
  ///
  /// An unreadable or missing method keeps the PROVIDER assumption — the same
  /// default the backend uses — so a CamerPay collection is never silently
  /// refunded as if it had come out of the drawer.
  static RefundLane lane(String? method) =>
      isCash(method) ? RefundLane.cash : RefundLane.provider;

  /// Meaningful only on the provider lane: the refund dialog asks for a CamerPay
  /// reference there and for nothing on a cash refund.
  static bool needsProviderReference(String? method) =>
      lane(method) == RefundLane.provider;

  /// A translated heading for the refund dialog.
  static String titleKey(String? method) =>
      isCash(method) ? 'refundLaneCashTitle' : 'refundLaneProviderTitle';

  /// A translated sentence explaining where the money goes back.
  static String hintKey(String? method) =>
      isCash(method) ? 'refundLaneCashHint' : 'refundLaneProviderHint';

  /// A short label for the return dialog's total line.
  static String returnLabelKey(String? method) =>
      isCash(method) ? 'returnLaneCash' : 'returnLaneProvider';

  /// A short label for the refund record ("Cash (drawer)" / "CamerPay · MTN"), so
  /// the manager sees the method that is about to be stored rather than guessing.
  static String methodLabel(String? method) {
    final canonical = normalize(method);
    switch (canonical) {
      case 'cash':
        return 'Cash';
      case 'mtn':
        return 'MTN MoMo';
      case 'orange':
        return 'Orange Money';
      case 'card':
        return 'Card';
      case '':
        return 'CamerPay';
      default:
        return canonical;
    }
  }
}
