// utils/recipeStock.js
// Which ingredients a sale takes off the shelf.
//
// WHY THIS IS WHOLE-UNIT ONLY. Stock is a whole-unit ledger: `inventory.quantity` is an
// integer everywhere in the app, and the atomic move (applyStockDelta) refuses to go
// negative. A recipe pour is fractional (0.05 of a bottle), and writing 0.05 into that
// ledger would either fail or silently truncate to zero — a wrong number, which is the
// one thing this feature must never produce. So a fractional line is NOT deducted: it
// comes back in `notTracked` and is reported, so the shop is told instead of quietly
// misled.
//
// That matches the business this serves: a whole-unit retailer (bottles, cans, crates).
// The fractional case is the exception, and it is named as such.
//
// Pure, so the rule is testable without a database (tests/recipe_stock.test.js).

/// A line the sale cannot move, and why.
const NOT_TRACKED = {
  /// A pour (0.05 of a bottle): the ledger cannot hold a fraction.
  FRACTIONAL: 'fractional',
  /// Ice, a garnish, anything not in the catalogue: nothing to move.
  NOT_IN_CATALOGUE: 'not_in_catalogue',
  /// The drink is its own ingredient: the sale already took it off the shelf.
  SELF: 'self',
  /// A stocked ingredient without enough on the shelf right now.
  INSUFFICIENT_STOCK: 'insufficient_stock',
  /// A stocked ingredient with no inventory row at all.
  NOT_STOCKED: 'not_stocked',
};

function toNumber(value) {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function nameOf(line) {
  if (!line) return '';
  return String(line.ingredient_name ?? line.ingredientName ?? '').trim();
}

function idOf(line) {
  if (!line) return null;
  const id = line.ingredient_drink_id ?? line.ingredientDrinkId;
  if (id === null || id === undefined) return null;
  const text = String(id).trim();
  return text === '' ? null : text;
}

/**
 * Plans the ingredient movements for a sale.
 *
 * @param {object} options
 * @param {Array}  options.lines       drink_recipes rows for the sold drink
 * @param {number} options.unitsSold   how many of the drink were sold
 * @param {string|number|null} options.selfDrinkId the drink being sold
 * @returns {{moves: Array<{drinkId: string, name: string, quantity: number}>,
 *            notTracked: Array<{name: string, quantity: number, why: string}>}}
 */
function planIngredientMoves({ lines = [], unitsSold = 0, selfDrinkId = null } = {}) {
  const moves = [];
  const notTracked = [];
  const sold = Math.trunc(toNumber(unitsSold) ?? 0);
  if (sold <= 0) return { moves, notTracked };

  for (const line of lines) {
    const name = nameOf(line);
    const ingredientId = idOf(line);
    const wanted = (toNumber(line && line.quantity) ?? 0) * sold;

    if (ingredientId === null) {
      // Nothing in the catalogue to move.
      notTracked.push({ name, quantity: wanted, why: NOT_TRACKED.NOT_IN_CATALOGUE });
      continue;
    }
    if (selfDrinkId !== null && ingredientId === String(selfDrinkId).trim()) {
      // A bottle served by the glass, or a bundle of itself: the sale already took
      // the drink off the shelf, so moving it again would count it twice.
      notTracked.push({ name, quantity: wanted, why: NOT_TRACKED.SELF });
      continue;
    }
    if (!Number.isInteger(wanted) || wanted < 1) {
      notTracked.push({ name, quantity: wanted, why: NOT_TRACKED.FRACTIONAL });
      continue;
    }
    moves.push({ drinkId: ingredientId, name, quantity: wanted });
  }

  return { moves, notTracked };
}

module.exports = { NOT_TRACKED, planIngredientMoves };
