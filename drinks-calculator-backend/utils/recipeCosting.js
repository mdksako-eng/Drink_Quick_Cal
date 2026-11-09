// utils/recipeCosting.js
// Pure recipe / pour-cost maths — no Express, no DB, unit tested.
//
// WHY THIS EXISTS. `drinks.purchase_price` already answers "what did this unit
// cost me" for a drink that is bought and resold whole. It says nothing about a
// drink that is MADE — a cocktail, a bottle sold by the glass, a mixed serve.
// Those have a real cost (the sum of their ingredients) and without it the
// margin on the best-selling item in the shop is invisible.
//
// Two rules are inherited from the Reports profit maths
// (lib/utils/report_profit_helper.dart), because they are what stop a cost report
// from lying:
//   1. A price of 0 or a missing price is "no cost on record", never a real 0.
//      A line whose price is unknown is left OUT of the cost and COUNTED, so the
//      caller can show the caveat instead of a flattering 100 % margin.
//   2. Nothing is guessed. When a line cannot be priced the recipe cost is a
//      lower bound and says so (`complete: false`).
//
// UNITS. Quantities are fractional — 0.05 of a litre is a normal pour — so every
// figure here is a plain Number and is never rounded: rounding is a display
// concern. A price paid for a PACK (a crate of 24) is divided by its pack size;
// that is the only place `packSize` is used, and it is always explicit.

// WHO DECIDES WHAT: what the shop pays for its stock is the shop's own business.
// A manager (or the owner) sets a recipe and sees a margin; the same rule the
// container list and the purchasing routes already apply.
const { isManagerRole } = require('./customerApproval');

const RECIPE_LIMITS = Object.freeze({
  /// A recipe with more lines than this is a data-entry accident, not a drink.
  maxLines: 60,
  /// How deep a recipe may reference another made drink (a pre-mix) before we
  /// call it a loop. Five is already more than any real bar stack.
  maxDepth: 5,
  /// A quantity above this is a typo (24 crates are fine; 24000 is not).
  maxQuantity: 100000,
});

/// The pour cost a bar normally aims at, used for the "charge X" hint.
const DEFAULT_TARGET_POUR_COST = 20;

function toNumber(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  const parsed = Number(String(value).trim());
  return Number.isFinite(parsed) ? parsed : null;
}

/// A cost of 0 (or less) means "no cost on record", never a real zero — the same
/// rule the app's profit helper applies. A *selling* price of 0 is left alone:
/// giving a unit away is a real thing a shop does.
function positiveOrNull(value) {
  const parsed = toNumber(value);
  return parsed === null || parsed <= 0 ? null : parsed;
}

/// Reads one line from the wire (snake_case from Postgres, camelCase from the
/// app) and normalises it. Tolerant on purpose: a NUMERIC column arrives as the
/// string "1000.00".
function normaliseLine(raw = {}) {
  const rawId = raw.ingredientDrinkId ?? raw.ingredient_drink_id;
  return {
    ingredientDrinkId:
      rawId === null || rawId === undefined || rawId === '' ? null : String(rawId),
    ingredientName: String(raw.ingredientName ?? raw.ingredient_name ?? '')
      .trim()
      .slice(0, 120),
    quantity: toNumber(raw.quantity) ?? 0,
    unit: String(raw.unit ?? '').trim().slice(0, 20),
    /// The price as paid for one purchase unit, overriding the ingredient's own
    /// purchase price (an input whose price the shop has not stocked).
    unitCost: toNumber(raw.unitCost ?? raw.unit_cost),
    /// How many recipe units one purchase unit covers (a crate of 24 → 24).
    packSize: toNumber(raw.packSize ?? raw.pack_size),
  };
}

/// Checks a recipe before it is saved. Returns `{ ok, reason?, lines? }` so the
/// route can answer with the exact message.
///
/// The self-reference check matters: without it `Cocktail → Cocktail` would
/// recurse forever when the cost is resolved.
function validateRecipe(lines, { drinkId = null } = {}) {
  if (!Array.isArray(lines) || lines.length === 0) {
    return { ok: false, reason: 'A recipe needs at least one ingredient' };
  }
  if (lines.length > RECIPE_LIMITS.maxLines) {
    return {
      ok: false,
      reason: `A recipe cannot hold more than ${RECIPE_LIMITS.maxLines} ingredients`,
    };
  }

  const normalised = [];
  const seen = new Set();
  for (const raw of lines) {
    const line = normaliseLine(raw);

    if (!line.ingredientDrinkId && !line.ingredientName) {
      return { ok: false, reason: 'Every ingredient needs a drink or a name' };
    }
    if (
      drinkId !== null &&
      line.ingredientDrinkId !== null &&
      String(line.ingredientDrinkId) === String(drinkId)
    ) {
      return { ok: false, reason: 'A drink cannot be made from itself' };
    }
    if (!(line.quantity > 0)) {
      return { ok: false, reason: 'Every ingredient needs a quantity above zero' };
    }
    if (line.quantity > RECIPE_LIMITS.maxQuantity) {
      return { ok: false, reason: 'That quantity is too large to be real' };
    }

    // One row per ingredient: the same input twice would split one pour into two
    // and quietly double the cost.
    const key = line.ingredientDrinkId ?? `name:${line.ingredientName.toLowerCase()}`;
    if (seen.has(key)) {
      return { ok: false, reason: 'The same ingredient is listed twice' };
    }
    seen.add(key);
    normalised.push(line);
  }

  return { ok: true, lines: normalised };
}

/// What one recipe line costs, or null when no price is on record.
///
/// `ingredient` is the catalogue row (`{ purchasePrice, unitsPerPack }`) when the
/// line points at a stocked drink. The explicit `unitCost` on the line wins, so a
/// shop can price an input the catalogue has never heard of.
function lineCost(line, ingredient = null) {
  const override = positiveOrNull(line.unitCost);
  const listed = positiveOrNull(
    ingredient ? ingredient.purchasePrice ?? ingredient.purchase_price : null
  );
  const paid = override ?? listed;
  if (paid === null) return null;

  // A price for a pack covers packSize units; divide before multiplying by the
  // pour, never after (0.05 × a crate price would be nonsense).
  const pack =
    positiveOrNull(line.packSize) ??
    positiveOrNull(ingredient ? ingredient.unitsPerPack ?? ingredient.units_per_pack : null) ??
    1;

  return (paid / pack) * line.quantity;
}

/// Prices a flat list of lines. `priceFor(drinkId)` returns the catalogue row for
/// a stocked ingredient, or null.
///
/// Returns the cost, the lines that could be priced, and the names of the ones
/// that could not. `complete` is false as soon as anything is missing: the caller
/// shows the caveat rather than a margin that looks better than it is.
function recipeCost(lines, priceFor = () => null) {
  const list = Array.isArray(lines) ? lines : [];
  const costed = [];
  const uncosted = [];
  let cost = 0;

  for (const raw of list) {
    const line = normaliseLine(raw);
    const ingredient = line.ingredientDrinkId ? priceFor(line.ingredientDrinkId) : null;
    const amount = lineCost(line, ingredient);
    if (amount === null) {
      uncosted.push(line.ingredientName || line.ingredientDrinkId || 'unnamed');
      continue;
    }
    cost += amount;
    costed.push({ ...line, cost: amount });
  }

  return { cost, costed, uncosted, complete: uncosted.length === 0 && list.length > 0 };
}

/// The cost of ONE unit of `drinkId`, following recipes into recipes.
///
/// An ingredient may itself be a made drink (a pre-mix, a house syrup), so this
/// recurses. Two guards, both needed:
///   * `trail` catches a loop (A → B → A) and stops with `cycle` set, instead of
///     recursing until the stack dies;
///   * `maxDepth` stops a chain that is deep but not circular.
///
/// A branch that cannot be priced contributes 0 and is reported in `uncosted`,
/// so the total is a lower bound and the caller knows it.
function resolveCost({
  drinkId,
  recipes = {},
  priceFor = () => null,
  depth = 0,
  trail = [],
} = {}) {
  const key = String(drinkId);

  if (trail.includes(key)) {
    return { cost: 0, uncosted: [key], complete: false, cycle: trail.concat(key), tooDeep: false };
  }
  if (depth >= RECIPE_LIMITS.maxDepth) {
    return { cost: 0, uncosted: [key], complete: false, cycle: null, tooDeep: true };
  }

  const lines = recipes[key];

  // Not a made drink: its own purchase price is the cost, and if that is missing
  // there is nothing to report but the gap.
  if (!Array.isArray(lines) || lines.length === 0) {
    const row = priceFor(key);
    const own = positiveOrNull(row ? row.purchasePrice ?? row.purchase_price : null);
    if (own === null) {
      return { cost: 0, uncosted: [key], complete: false, cycle: null, tooDeep: false };
    }
    return { cost: own, uncosted: [], complete: true, cycle: null, tooDeep: false };
  }

  let cost = 0;
  const uncosted = [];
  let complete = true;
  let cycle = null;
  let tooDeep = false;

  for (const raw of lines) {
    const line = normaliseLine(raw);
    let perUnit = null;

    if (line.ingredientDrinkId) {
      const sub = resolveCost({
        drinkId: line.ingredientDrinkId,
        recipes,
        priceFor,
        depth: depth + 1,
        trail: trail.concat(key),
      });
      if (sub.cost > 0) perUnit = sub.cost;
      if (!sub.complete) {
        complete = false;
        uncosted.push(...sub.uncosted);
      }
      if (sub.cycle) cycle = cycle || sub.cycle;
      if (sub.tooDeep) tooDeep = true;
    } else {
      // An input the catalogue does not stock (ice, a garnish): only the explicit
      // price on the line can value it.
      perUnit = positiveOrNull(line.unitCost);
    }

    if (perUnit === null) {
      complete = false;
      if (line.ingredientName) uncosted.push(line.ingredientName);
      continue;
    }

    const pack = positiveOrNull(line.packSize) ?? 1;
    cost += (perUnit / pack) * line.quantity;
  }

  return { cost, uncosted, complete, cycle, tooDeep };
}

/// Cost as a share of the selling price, in percent. 0 when there is no price to
/// compare against (never NaN, never Infinity).
function pourCostPercent(cost, sellingPrice) {
  const sell = toNumber(sellingPrice) ?? 0;
  const spent = toNumber(cost) ?? 0;
  if (!(sell > 0)) return 0;
  return (spent / sell) * 100;
}

/// What is left per unit once the ingredients are paid for.
function marginPerUnit(cost, sellingPrice) {
  return (toNumber(sellingPrice) ?? 0) - (toNumber(cost) ?? 0);
}

/// Margin on the selling price, in percent. 0 when nothing is charged.
function marginPercent(cost, sellingPrice) {
  const sell = toNumber(sellingPrice) ?? 0;
  if (!(sell > 0)) return 0;
  return (marginPerUnit(cost, sellingPrice) / sell) * 100;
}

/// The price that would hold `targetPercent` pour cost — the sellable sentence
/// ("to keep 20 %, charge X"). Null when there is nothing to price or the target
/// is not a usable percentage.
function priceForTargetPourCost(cost, targetPercent) {
  const spent = positiveOrNull(cost);
  const target = toNumber(targetPercent);
  if (spent === null || target === null || target <= 0 || target > 100) return null;
  return spent / (target / 100);
}

/// Everything the drink card and the costing report show for one drink, from one
/// recipe and one selling price, so the figures always agree.
function drinkCosting({ drink = {}, lines = [], priceFor = () => null, target = DEFAULT_TARGET_POUR_COST } = {}) {
  const priced = recipeCost(lines, priceFor);
  const selling = toNumber(drink.price ?? drink.sellingPrice ?? drink.selling_price) ?? 0;
  return {
    cost: priced.cost,
    complete: priced.complete,
    uncosted: priced.uncosted,
    hasRecipe: Array.isArray(lines) && lines.length > 0,
    sellingPrice: selling,
    margin: marginPerUnit(priced.cost, selling),
    marginPercent: marginPercent(priced.cost, selling),
    pourCostPercent: pourCostPercent(priced.cost, selling),
    targetPrice: priceForTargetPourCost(priced.cost, target),
  };
}

/// Worst pour cost first — the order a manager acts on.
function rankByPourCost(rows = []) {
  return [...rows].sort(
    (a, b) => (toNumber(b.pourCostPercent) ?? 0) - (toNumber(a.pourCostPercent) ?? 0)
  );
}

/// Whether `user` may set a recipe, change a cost or read a margin.
///
/// A manager or the company owner — the roles that already commit the shop's
/// money elsewhere. Staff sell the drink; they do not need to know what it cost.
function canManageRecipes(user) {
  if (!user) return { ok: false, reason: 'Authentication required' };
  if (isManagerRole(user.role)) return { ok: true };
  return { ok: false, reason: 'Only a manager can change a recipe or a cost' };
}

/// A usable target pour cost: a percentage above 0 and up to 100, rounded to two
/// decimals. Null when the value cannot be used, so a caller REFUSES it instead of
/// substituting the default behind the manager's back — a silently ignored setting
/// looks exactly like a saved one.
function normaliseTargetPourCost(value) {
  const parsed = toNumber(value);
  if (parsed === null || parsed <= 0 || parsed > 100) return null;
  return Math.round(parsed * 100) / 100;
}

module.exports = {
  RECIPE_LIMITS,
  DEFAULT_TARGET_POUR_COST,
  canManageRecipes,
  normaliseLine,
  validateRecipe,
  normaliseTargetPourCost,
  lineCost,
  recipeCost,
  resolveCost,
  pourCostPercent,
  marginPerUnit,
  marginPercent,
  priceForTargetPourCost,
  drinkCosting,
  rankByPourCost,
};


