// tests/recipe_stock.test.js
// Phase B: which ingredients a sale takes off the shelf.
//
// The rule these tests pin down is the one that keeps stock honest. Stock is a
// WHOLE-UNIT ledger (inventory.quantity is an integer everywhere in the app, and the
// atomic move refuses to go negative), so a fractional pour is NEVER written into it:
// it would either fail or truncate to zero. It is reported instead.
const { NOT_TRACKED, planIngredientMoves } = require('../utils/recipeStock');

const line = (over = {}) => ({
  ingredient_drink_id: null,
  ingredient_name: '',
  quantity: 1,
  ...over,
});

describe('planning the ingredients a sale moves', () => {
  test('whole units of a stocked ingredient come off the shelf', () => {
    const { moves, notTracked } = planIngredientMoves({
      lines: [
        line({
          ingredient_drink_id: 'beer-33',
          ingredient_name: 'Bière 33cl',
          quantity: 2,
        }),
      ],
      unitsSold: 3,
    });
    expect(notTracked).toEqual([]);
    expect(moves).toEqual([
      { drinkId: 'beer-33', name: 'Bière 33cl', quantity: 6 },
    ]);
  });

  test('a fractional pour is reported, never deducted', () => {
    // 0.05 of a bottle is a normal pour, and the ledger cannot hold it.
    const { moves, notTracked } = planIngredientMoves({
      lines: [
        line({
          ingredient_drink_id: 'gin-70',
          ingredient_name: 'Gin 70cl',
          quantity: 0.05,
        }),
      ],
      unitsSold: 4,
    });
    expect(moves).toEqual([]);
    expect(notTracked).toEqual([
      { name: 'Gin 70cl', quantity: 0.2, why: NOT_TRACKED.FRACTIONAL },
    ]);
  });

  test('a decimal line that lands on a whole number still moves', () => {
    // 2.5 crates per sale × 4 sales = 10 whole crates.
    const { moves, notTracked } = planIngredientMoves({
      lines: [line({ ingredient_drink_id: 'crate', quantity: 2.5 })],
      unitsSold: 4,
    });
    expect(notTracked).toEqual([]);
    expect(moves[0].quantity).toBe(10);
  });

  test('an input the catalogue does not stock is reported, not moved', () => {
    const { moves, notTracked } = planIngredientMoves({
      lines: [line({ ingredient_name: 'Ice', quantity: 1 })],
      unitsSold: 1,
    });
    expect(moves).toEqual([]);
    expect(notTracked).toEqual([
      { name: 'Ice', quantity: 1, why: NOT_TRACKED.NOT_IN_CATALOGUE },
    ]);
  });

  test('a drink that is its own ingredient is not counted twice', () => {
    // The sale already took the drink itself off the shelf.
    const { moves, notTracked } = planIngredientMoves({
      lines: [
        line({ ingredient_drink_id: '7', ingredient_name: 'Bottle', quantity: 1 }),
      ],
      unitsSold: 1,
      selfDrinkId: '7',
    });
    expect(moves).toEqual([]);
    expect(notTracked[0].why).toBe(NOT_TRACKED.SELF);
  });

  test('no sale means nothing moves', () => {
    const { moves, notTracked } = planIngredientMoves({
      lines: [line({ ingredient_drink_id: 'beer', quantity: 1 })],
      unitsSold: 0,
    });
    expect(moves).toEqual([]);
    expect(notTracked).toEqual([]);
  });

  test('an empty or missing recipe is handled', () => {
    expect(planIngredientMoves().moves).toEqual([]);
    expect(planIngredientMoves({}).moves).toEqual([]);
    expect(planIngredientMoves({ lines: [], unitsSold: 5 }).moves).toEqual([]);
  });

  test('a zero or negative line never moves stock', () => {
    const { moves, notTracked } = planIngredientMoves({
      lines: [line({ ingredient_drink_id: 'beer', quantity: 0 })],
      unitsSold: 2,
    });
    expect(moves).toEqual([]);
    expect(notTracked[0].why).toBe(NOT_TRACKED.FRACTIONAL);
  });

  test('numbers sent as strings still work', () => {
    const { moves } = planIngredientMoves({
      lines: [line({ ingredient_drink_id: 'beer', quantity: '2' })],
      unitsSold: '2',
    });
    expect(moves[0].quantity).toBe(4);
  });
});
