// test/recipe_cost_test.dart
// Recipe / pour cost: what a MADE drink costs (a cocktail, a bottle by the glass).
//
// These tests exist because a wrong pour cost moves prices: a missing price must
// never read as a free ingredient, and a pack price must be divided before it is
// multiplied. See the header of utils/recipe_cost_helper.dart.
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_calculator_fixed/utils/recipe_cost_helper.dart';

const IngredientPrice _gin = IngredientPrice(purchasePrice: 12000);
const IngredientPrice _tonicCrate =
    IngredientPrice(purchasePrice: 24000, packSize: 24);

IngredientPrice? priceFor(String id) {
  switch (id) {
    case 'gin-70':
      return _gin;
    case 'tonic-33':
      return _tonicCrate;
    case 'lime':
      return const IngredientPrice(purchasePrice: 100);
    default:
      return null;
  }
}

void main() {
  group('pricing one line', () {
    test('uses the ingredient purchase price, and divides a pack price first', () {
      // 0.05 of a 12 000 bottle.
      expect(
        RecipeCostHelper.lineCost(
          const RecipeCostLine(quantity: 0.05, ingredientDrinkId: 'gin-70'),
          _gin,
        ),
        closeTo(600, 0.001),
      );
      // One bottle out of a crate of 24 → 1 000, not 24 000.
      expect(
        RecipeCostHelper.lineCost(
          const RecipeCostLine(quantity: 1, ingredientDrinkId: 'tonic-33'),
          _tonicCrate,
        ),
        closeTo(1000, 0.001),
      );
    });

    test('an explicit cost on the line wins over the catalogue', () {
      expect(
        RecipeCostHelper.lineCost(
          const RecipeCostLine(quantity: 1, unitCost: 500, ingredientDrinkId: 'gin-70'),
          _gin,
        ),
        closeTo(500, 0.001),
      );
    });

    test('a price of 0 is "no cost on record", never a free ingredient', () {
      expect(
        RecipeCostHelper.lineCost(const RecipeCostLine(quantity: 1), null),
        isNull,
      );
      expect(
        RecipeCostHelper.lineCost(
          const RecipeCostLine(quantity: 1),
          const IngredientPrice(purchasePrice: 0),
        ),
        isNull,
      );
    });
  });

  group('pricing a recipe', () {
    test('sums the lines', () {
      final costing = RecipeCostHelper.costing(
        sellingPrice: 3000,
        priceFor: priceFor,
        lines: const [
          RecipeCostLine(ingredientDrinkId: 'gin-70', quantity: 0.05), // 600
          RecipeCostLine(ingredientDrinkId: 'tonic-33', quantity: 1), // 1 000
          RecipeCostLine(ingredientDrinkId: 'lime', quantity: 0.5), // 50
        ],
      );
      expect(costing.cost, closeTo(1650, 0.001));
      expect(costing.complete, isTrue);
      expect(costing.uncosted, isEmpty);
    });

    test('an unpriced line is counted and left out, never counted as zero', () {
      final costing = RecipeCostHelper.costing(
        sellingPrice: 3000,
        priceFor: priceFor,
        lines: const [
          RecipeCostLine(ingredientDrinkId: 'gin-70', quantity: 0.05), // 600
          RecipeCostLine(ingredientName: 'Ice', quantity: 2), // no price
        ],
      );
      expect(costing.cost, closeTo(600, 0.001));
      expect(costing.complete, isFalse);
      expect(costing.uncosted, ['Ice']);
      expect(costing.hasCaveat, isTrue);
    });

    test('a drink with no recipe is not costed, and says so', () {
      final costing = RecipeCostHelper.costing(
        sellingPrice: 1000,
        priceFor: priceFor,
        lines: const [],
      );
      expect(costing.hasRecipe, isFalse);
      expect(costing.complete, isFalse);
      expect(costing.isUnknown, isTrue);
    });
  });

  group('pour cost and margin', () {
    test('pour cost is the cost as a share of the price', () {
      expect(RecipeCostHelper.pourCostPercent(500, 2500), closeTo(20, 0.001));
      expect(RecipeCostHelper.pourCostPercent(1650, 3000), closeTo(55, 0.001));
    });

    test('no selling price gives 0, never NaN or Infinity', () {
      expect(RecipeCostHelper.pourCostPercent(500, 0), 0);
      expect(RecipeCostHelper.marginPercent(500, 0), 0);
    });

    test('margin per unit and as a percent', () {
      expect(RecipeCostHelper.marginPerUnit(500, 2500), closeTo(2000, 0.001));
      expect(RecipeCostHelper.marginPercent(500, 2500), closeTo(80, 0.001));
    });

    test('the price that holds a target pour cost', () {
      expect(RecipeCostHelper.priceForTargetPourCost(500, 20), closeTo(2500, 0.001));
      expect(RecipeCostHelper.priceForTargetPourCost(500, 0), isNull);
      expect(RecipeCostHelper.priceForTargetPourCost(500, 150), isNull);
      expect(RecipeCostHelper.priceForTargetPourCost(0, 20), isNull);
    });
  });

  group('the drink card figures', () {
    test('a cocktail end to end', () {
      final costing = RecipeCostHelper.costing(
        sellingPrice: 3000,
        priceFor: priceFor,
        lines: const [
          RecipeCostLine(ingredientDrinkId: 'gin-70', quantity: 0.05), // 600
          RecipeCostLine(ingredientDrinkId: 'tonic-33', quantity: 1), // 1 000
        ],
      );
      expect(costing.cost, closeTo(1600, 0.001));
      expect(costing.margin, closeTo(1400, 0.001));
      expect(costing.pourCostPercent, closeTo(53.33, 0.01));
      // 1 600 / 20 % — the price that would hold the target.
      expect(costing.targetPrice, closeTo(8000, 0.001));
    });
  });

  group('ranking', () {
    test('worst pour cost first, and drinks nobody can cost sort last', () {
      final ranked = RecipeCostHelper.rankByPourCost({
        'Beer': const RecipeCosting(
          cost: 300,
          complete: true,
          uncosted: [],
          sellingPrice: 1000,
          hasRecipe: false,
        ),
        'Cocktail': const RecipeCosting(
          cost: 1600,
          complete: true,
          uncosted: [],
          sellingPrice: 3000,
          hasRecipe: true,
        ),
        'Mystery': RecipeCosting.empty,
      });
      expect(
        ranked.map((entry) => entry.key).toList(),
        ['Cocktail', 'Beer', 'Mystery'],
      );
    });
  });

  group('parsing what the backend sends', () {
    test('a line and a costing row survive the wire', () {
      final line = RecipeCostLine.fromJson({
        'ingredient_drink_id': 'gin-70',
        'ingredient_name': 'Gin 70cl',
        'quantity': '0.05',
        'unit': 'l',
        'unit_cost': null,
        'pack_size': 1,
      });
      expect(line.ingredientDrinkId, 'gin-70');
      expect(line.quantity, closeTo(0.05, 0.0001));
      expect(line.unitCost, isNull);
      expect(line.isStocked, isTrue);

      final costing = RecipeCosting.fromJson({
        'cost': '1600.00',
        'complete': true,
        'uncosted': <String>[],
        'selling_price': 3000,
        'has_recipe': true,
        'target_pour_cost': 20,
      });
      expect(costing.cost, closeTo(1600, 0.001));
      expect(costing.complete, isTrue);
      expect(costing.pourCostPercent, closeTo(53.33, 0.01));
    });
  });
}

