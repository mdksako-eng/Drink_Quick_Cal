// utils/refundRecord.js
// Refunds are RECORDED here; the money itself moves in the provider's dashboard
// (CamerPay), because no refund API is wired into this backend.
//
// That makes the record the only proof the company has: who refunded what, why,
// and against which provider reference. So the rules are strict:
//   • a reason is required (an unexplained refund is unauditable);
//   • the amount must be positive and never exceed what is still refundable on the
//     order (a refund cannot give back more than was collected);
//   • a provider reference is expected, because that is what ties our row to the
//     line on the provider statement.
// The record must also say WHICH LANE the money came back through, because the
// two are not interchangeable: a sale collected through CamerPay (mtn / orange /
// card) is refunded at CamerPay and tied to its provider reference, while a sale
// paid in cash is refunded out of the drawer and has no provider line at all.
// Filing every refund as a provider one — the old default — made the books wrong
// twice over: a cash refund looked like it had gone back to CamerPay, and a
// CamerPay refund was invisible.
// Pure — no Express, no DB — so every rule is unit tested.
function toAmount(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.round(number * 100) / 100 : NaN;
}

// ---------------------------------------------------------------- refund lanes
// The vocabulary the app, CamerPay and this server each spell differently,
// normalised to one set. The app sends the till's PaymentMethod name ('cash',
// 'mtnMobileMoney', 'orangeMoney', 'card'); a CamerPay collection stores its own
// rail ('mtn', 'orange', 'card'); an order that predates the column has nothing.
// All of them have to land on one word, or a refund ends up in the wrong lane.
const RAIL_ALIASES = {
  cash: 'cash',
  mtn: 'mtn',
  momo: 'mtn',
  mtnmobilemoney: 'mtn',
  mtnmomo: 'mtn',
  orange: 'orange',
  orangemoney: 'orange',
  card: 'card',
  visa: 'card',
  stripe: 'card',
  paypal: 'paypal',
};

/**
 * One spelling of a payment method, or '' when there is not enough to say.
 * Case, spaces, dashes and underscores are ignored, so 'MTN MoMo' and 'mtn_momo'
 * are recognised as the same rail.
 */
function canonicalMethod(value) {
  const raw = (value == null ? '' : String(value)).trim().toLowerCase();
  if (!raw) return '';
  return RAIL_ALIASES[raw.replace(/[^a-z0-9]/g, '')] || raw;
}

/** Is this a cash sale — the only money a drawer is accountable for? */
function isCashMethod(value) {
  return canonicalMethod(value) === 'cash';
}

/**
 * Which lane a refund travels.
 *   * 'cash' — the money comes back out of the drawer, and there is no provider
 *     statement to quote, so no reference is expected;
 *   * 'provider' — a CamerPay collection: the manager issues the refund in the
 *     CamerPay dashboard and records the reference that ties it to the statement.
 *
 * A missing method keeps the historical provider assumption (and its "no
 * reference" warning) rather than silently filing the refund as cash, which would
 * hide a CamerPay collection the drawer was never responsible for.
 */
function refundLane(method) {
  const canonical = canonicalMethod(method);
  if (canonical === 'cash') {
    return { lane: 'cash', method: 'cash', provider: null, assumed: false };
  }
  return {
    lane: 'provider',
    method: canonical || 'card',
    provider: 'campay',
    assumed: canonical === '',
  };
}

/**
 * @param {{amount: *, reason: *, reference?: *, method?: *, orderTotal?: number,
 *          alreadyRefunded?: number}} args
 * @returns {{ok: boolean, reason?: string, amount?: number, note?: string,
 *            lane?: 'cash'|'provider', method?: string}}
 */
function validateRefund({
  amount,
  reason,
  reference,
  method,
  orderTotal = null,
  alreadyRefunded = 0,
} = {}) {
  const value = toAmount(amount);
  if (!Number.isFinite(value) || value <= 0) {
    return { ok: false, reason: 'A refund needs a positive amount' };
  }

  const text = (reason || '').toString().trim();
  if (!text) return { ok: false, reason: 'A reason is required to record a refund' };
  if (text.length > 200) {
    return { ok: false, reason: 'The reason is too long (200 characters max)' };
  }

  if (orderTotal != null) {
    const total = toAmount(orderTotal);
    const already = toAmount(alreadyRefunded) || 0;
    if (Number.isFinite(total)) {
      const remaining = Math.round((total - already) * 100) / 100;
      if (value > remaining + 0.001) {
        return {
          ok: false,
          reason: `This order has ${remaining} left to refund`,
        };
      }
    }
  }

  const ref = (reference || '').toString().trim();
  const lane = refundLane(method);

  // A CASH refund is proved by the drawer, not by a provider statement: there is
  // no CamerPay line to quote, so no reference is expected and none is missed. A
  // PROVIDER refund is the opposite — the reference is what ties our row to the
  // statement — so a missing one is recorded from the start for a manager to
  // chase. Either way the verdict carries the METHOD, so the caller stores the
  // row in the lane the money actually travelled.
  if (lane.lane === 'cash') {
    return {
      ok: true,
      amount: value,
      lane: lane.lane,
      method: lane.method,
      note: null,
    };
  }
  return {
    ok: true,
    amount: value,
    lane: lane.lane,
    method: lane.method,
    // Not fatal: an operator may not have the reference to hand, but the record
    // says so plainly so a manager can chase it.
    note: ref ? null : 'no provider reference recorded',
  };
}

/** The row to store for an approved refund. */
function buildRefundRow({
  companyId,
  orderId,
  amount,
  reason,
  reference = '',
  method = 'card',
  performedBy,
  performedByName,
  status = 'approved',
  createdAt = new Date(),
}) {
  return {
    company_id: companyId,
    order_id: orderId ?? null,
    amount,
    reason: (reason || '').toString().trim(),
    reference: (reference || '').toString().trim(),
    method: refundLane(method).method,
    performed_by: performedBy ?? null,
    performed_by_name: (performedByName || '').toString().trim(),
    status,
    created_at: createdAt,
  };
}

module.exports = {
  canonicalMethod,
  isCashMethod,
  refundLane,
  validateRefund,
  buildRefundRow,
};
