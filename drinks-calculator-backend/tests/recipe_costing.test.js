// tests/recipe_costing.test.js
// Recipe / pour cost: what a MADE drink costs (cocktails, a bottle by the glass).
//
// The figures here are money the owner acts on — a wrong pour cost moves prices —
// so the rules are pinned: a missing price is never read as a free ingredient,
// a pack price is divided before it is multiplied, and a recipe that loops stops
// instead of hanging the server.
const {
  RECIPE_LIMITS,
  validateRecipe,
  lineCost,
  recipeCost,
  resolveCost,
  pourCostPercent,
  marginPerUnit,
  marginPercent,
  priceForTargetPourCost,
  normaliseTargetPourCost,
  drinkCosting,
  rankByPourCost,
} = require('../utils/recipeCosting');

// The catalogue rows a priceFor() would return.
const catalogue = {
  'gin-70': { purchasePrice: 12000, unitsPerPack: 1 },    // 12 000 the bottle
  'tonic-33': { purchasePrice: 24000, unitsPerPack: 24 }, // 24 000 the crate of 24
  lime: { purchasePrice: 100 },                            // a lime
};

const priceFor = (id) => catalogue[String(id)] || null;

describe('validating a recipe', () => {
  test('refuses an empty recipe, a self-reference and a zero pour', () => {
    expect(validateRecipe([]).ok).toBe(false);
    expect(
      validateRecipe([{ ingredientDrinkId: 'gin-70', quantity: 1 }], { drinkId: 'gin-70' }).ok
    ).toBe(false);
    expect(validateRecipe([{ ingredientDrinkId: 'gin-70', quantity: 0 }]).ok).toBe(false);
    expect(validateRecipe([{ ingredientName: '', quantity: 1 }]).ok).toBe(false);
  });

  test('refuses the same ingredient twice — it would double the cost', () => {
    const twice = validateRecipe([
      { ingredientDrinkId: 'gin-70', quantity: 0.05 },
      { ingredientDrinkId: 'gin-70', quantity: 0.05 },
    ]);
    expect(twice.ok).toBe(false);
    expect(twice.reason).toMatch(/twice/i);
  });

  test('refuses a recipe longer than the limit', () => {
    const many = Array.from({ length: RECIPE_LIMITS.maxLines + 1 }, (_, i) => ({
      ingredientDrinkId: `d${i}`,
      quantity: 1,
    }));
    expect(validateRecipe(many).ok).toBe(false);
  });

  test('accepts a real recipe and normalises it', () => {
    const result = validateRecipe([
      { ingredient_drink_id: 'gin-70', quantity: '0.05', unit: 'l' },
      { ingredient_name: 'Lime', quantity: 0.5 },
    ]);
    expect(result.ok).toBe(true);
    expect(result.lines[0].ingredientDrinkId).toBe('gin-70');
    expect(result.lines[0].quantity).toBe(0.05);
    expect(result.lines[1].ingredientName).toBe('Lime');
  });
});

describe('pricing one line', () => {
  test('uses the ingredient purchase price, and a pack price is divided first', () => {
    // 0.05 of a 12 000 bottle.
    expect(lineCost({ quantity: 0.05 }, catalogue['gin-70'])).toBeCloseTo(600);
    // One bottle out of a crate of 24 → 1 000, not 24 000.
    expect(lineCost({ quantity: 1 }, catalogue['tonic-33'])).toBeCloseTo(1000);
  });

  test('an explicit unit cost on the line wins over the catalogue', () => {
    expect(lineCost({ quantity: 1, unitCost: 500 }, catalogue['gin-70'])).toBeCloseTo(500);
  });

  test('a price of 0 is "no cost on record", never a free ingredient', () => {
    expect(lineCost({ quantity: 1 }, { purchasePrice: 0 })).toBeNull();
    expect(lineCost({ quantity: 1 }, null)).toBeNull();
    expect(lineCost({ quantity: 1 }, {})).toBeNull();
  });
});

describe('pricing a recipe', () => {
  test('sums the lines', () => {
    const priced = recipeCost(
      [
        { ingredientDrinkId: 'gin-70', quantity: 0.05 }, // 600
        { ingredientDrinkId: 'tonic-33', quantity: 1 },  // 1 000
        { ingredientDrinkId: 'lime', quantity: 0.5 },    // 50
      ],
      priceFor
    );
    expect(priced.cost).toBeCloseTo(1650);
    expect(priced.complete).toBe(true);
    expect(priced.uncosted).toEqual([]);
  });

  test('an unpriced line is counted and left out, never counted as zero', () => {
    const priced = recipeCost(
      [
        { ingredientDrinkId: 'gin-70', quantity: 0.05 }, // 600
        { ingredientName: 'Ice', quantity: 2 },          // no price anywhere
      ],
      priceFor
    );
    expect(priced.cost).toBeCloseTo(600);
    expect(priced.complete).toBe(false);
    expect(priced.uncosted).toEqual(['Ice']);
  });

  test('nothing priced at all reports a lower bound of 0, flagged incomplete', () => {
    const priced = recipeCost([{ ingredientName: 'Ice', quantity: 2 }], priceFor);
    expect(priced.cost).toBe(0);
    expect(priced.complete).toBe(false);
  });
});

describe('resolving a cost through nested recipes', () => {
  const recipes = {
    cocktail: [{ ingredientDrinkId: 'premix', quantity: 0.2 }],
    premix: [{ ingredientDrinkId: 'gin-70', quantity: 0.5 }],
  };

  test('a made drink used as an ingredient is priced from its own recipe', () => {
    // 0.5 of a 12 000 bottle = 6 000 for the pre-mix; 0.2 of that = 1 200.
    const result = resolveCost({ drinkId: 'cocktail', recipes, priceFor });
    expect(result.cost).toBeCloseTo(1200);
    expect(result.complete).toBe(true);
  });

  test('a plain drink falls back to its own purchase price', () => {
    const result = resolveCost({ drinkId: 'gin-70', recipes: {}, priceFor });
    expect(result.cost).toBeCloseTo(12000);
    expect(result.complete).toBe(true);
  });

  test('a loop stops with the cycle reported instead of hanging', () => {
    const looped = {
      a: [{ ingredientDrinkId: 'b', quantity: 1 }],
      b: [{ ingredientDrinkId: 'a', quantity: 1 }],
    };
    const result = resolveCost({ drinkId: 'a', recipes: looped, priceFor });
    expect(result.complete).toBe(false);
    expect(result.cycle).toEqual(['a', 'b', 'a']);
  });

  test('a chain deeper than the limit stops', () => {
    const deep = {};
    for (let i = 0; i < RECIPE_LIMITS.maxDepth + 2; i += 1) {
      deep[`d${i}`] = [{ ingredientDrinkId: `d${i + 1}`, quantity: 1 }];
    }
    const result = resolveCost({ drinkId: 'd0', recipes: deep, priceFor });
    expect(result.complete).toBe(false);
    expect(result.tooDeep).toBe(true);
  });

  test('a drink with no price and no recipe reports the gap', () => {
    const result = resolveCost({ drinkId: 'unknown', recipes: {}, priceFor });
    expect(result.cost).toBe(0);
    expect(result.complete).toBe(false);
  });
});

describe('pour cost and margin', () => {
  test('pour cost is the cost as a share of the price', () => {
    expect(pourCostPercent(500, 2500)).toBeCloseTo(20);
    expect(pourCostPercent(1650, 3000)).toBeCloseTo(55);
  });

  test('no selling price gives 0, never NaN or Infinity', () => {
    expect(pourCostPercent(500, 0)).toBe(0);
    expect(pourCostPercent(500, null)).toBe(0);
    expect(marginPercent(500, 0)).toBe(0);
  });

  test('margin per unit and as a percent', () => {
    expect(marginPerUnit(500, 2500)).toBeCloseTo(2000);
    expect(marginPercent(500, 2500)).toBeCloseTo(80);
  });

  test('the price that holds a target pour cost', () => {
    expect(priceForTargetPourCost(500, 20)).toBeCloseTo(2500);
    expect(priceForTargetPourCost(1650, 25)).toBeCloseTo(6600);
    expect(priceForTargetPourCost(500, 0)).toBeNull();
    expect(priceForTargetPourCost(500, 150)).toBeNull();
    expect(priceForTargetPourCost(0, 20)).toBeNull();
  });

  describe('the target pour cost a company sets', () => {
    test('accepts a usable percentage and rounds it to two decimals', () => {
      expect(normaliseTargetPourCost(20)).toBe(20);
      expect(normaliseTargetPourCost('22.5')).toBe(22.5);
      expect(normaliseTargetPourCost(22.567)).toBe(22.57);
      // Giving the whole price to the pour is a choice, not an error.
      expect(normaliseTargetPourCost(100)).toBe(100);
    });

    test('refuses what cannot be used, instead of defaulting behind the manager', () => {
      expect(normaliseTargetPourCost(0)).toBeNull();
      expect(normaliseTargetPourCost(-1)).toBeNull();
      expect(normaliseTargetPourCost(100.5)).toBeNull();
      expect(normaliseTargetPourCost('abc')).toBeNull();
      expect(normaliseTargetPourCost(null)).toBeNull();
      expect(normaliseTargetPourCost(undefined)).toBeNull();
    });
  });
});

describe('the drink card figures', () => {
  test('a cocktail end to end', () => {
    const row = drinkCosting({
      drink: { id: 'cocktail', price: 3000 },
      lines: [
        { ingredientDrinkId: 'gin-70', quantity: 0.05 }, // 600
        { ingredientDrinkId: 'tonic-33', quantity: 1 },  // 1 000
      ],
      priceFor,
    });
    expect(row.cost).toBeCloseTo(1600);
    expect(row.hasRecipe).toBe(true);
    expect(row.complete).toBe(true);
    expect(row.margin).toBeCloseTo(1400);
    expect(row.pourCostPercent).toBeCloseTo(53.33, 1);
    expect(row.targetPrice).toBeCloseTo(8000); // 1 600 / 20 %
  });

  test('a drink with no recipe says so instead of pretending it is free', () => {
    const row = drinkCosting({ drink: { id: 'beer', price: 1000 }, lines: [], priceFor });
    expect(row.hasRecipe).toBe(false);
    expect(row.complete).toBe(false);
  });
});

describe('ranking', () => {
  test('worst pour cost first — the order a manager acts on', () => {
    const ranked = rankByPourCost([
      { drinkName: 'Beer', pourCostPercent: 30 },
      { drinkName: 'Cocktail', pourCostPercent: 62 },
      { drinkName: 'Wine', pourCostPercent: 45 },
    ]);
    expect(ranked.map((r) => r.drinkName)).toEqual(['Cocktail', 'Wine', 'Beer']);
  });
});

