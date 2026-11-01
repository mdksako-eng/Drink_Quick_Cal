// models/recipe_model.dart
// One row of the pour cost report: a drink, what it costs to make, what it earns.
//
// The COST itself is not stored here and not stored anywhere: it is computed by the
// backend from the ingredients' current purchase prices on every read
// (drinks-calculator-backend/utils/recipeCosting.js), so a supplier price change
// flows through every margin at once. This model only carries that answer.
//
// Postgres NUMERIC columns come back as strings ("1600.00") through the backend, so
// every number is parsed tolerantly — the same rule as container_model.dart.

import '../utils/recipe_cost_helper.dart';

class RecipeCostRow {
  const RecipeCostRow({
    required this.drinkId,
    required this.drinkName,
    required this.costing,
    this.hasRecipe = false,
    this.unitsSold = 0,
    this.profitInWindow = 0,
  });

  final String drinkId;
  final String drinkName;

  /// What it costs, what it earns and whether anything could not be priced.
  final RecipeCosting costing;

  /// True when the cost comes from a recipe rather than the drink's own purchase
  /// price. Both kinds appear in one report: a drink bought and resold whole is
  /// priced from what it was bought for.
  final bool hasRecipe;

  /// Units sold in the window, so the ranking can be read as money at stake rather
  /// than as a theoretical percentage.
  final int unitsSold;

  /// Margin × units in the window.
  final double profitInWindow;

  /// A drink nobody can cost yet: no recipe and no purchase price on record.
  bool get isUnknown => costing.isUnknown;

  /// The figures need a caveat on screen.
  bool get hasCaveat => costing.hasCaveat;

  factory RecipeCostRow.fromJson(Map<String, dynamic> json) => RecipeCostRow(
        drinkId: (json['drinkId'] ?? json['drink_id'] ?? '').toString(),
        drinkName: (json['drinkName'] ?? json['drink_name'] ?? '').toString(),
        costing: RecipeCosting.fromJson(json),
        hasRecipe: json['hasRecipe'] == true || json['has_recipe'] == true,
        unitsSold: _asInt(json['unitsSold'] ?? json['units_sold']),
        profitInWindow: _asDouble(json['profitInWindow'] ?? json['profit_in_window']) ?? 0,
      );
}

int _asInt(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}
