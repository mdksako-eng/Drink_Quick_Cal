// utils/recipe_cost_helper.dart
// The money side of a recipe, as pure functions so it can be tested without
// pumping a widget — the same shape as report_profit_helper.dart.
//
// WHY THIS EXISTS. `Drink.purchasePrice` answers "what did this unit cost me" for a
// drink bought and resold whole. It says nothing about a drink ASSEMBLED at the
// counter — a cocktail, a bottle sold by the glass — whose cost is the sum of its
// ingredients. That is where a bar's margin is really decided, and without it the
// margin on the best-selling item in the shop is invisible.
//
// Two rules, inherited from the Reports profit maths, because they are what stop a
// cost figure from lying:
//   1. A price of 0 or a missing price is "no cost on record", never a real 0. A
//      line that cannot be priced is left OUT of the cost and COUNTED, so the
//      screen shows the caveat instead of a flattering 100 % margin.
//   2. Nothing is guessed: [RecipeCosting.complete] is false as soon as anything is
//      missing, and the cost is then a lower bound.
//
// Quantities are fractional (0.05 of a litre is a normal pour), so nothing here is
// rounded: rounding is a display concern.

/// One ingredient line, as the editor and the API both carry it.
class RecipeCostLine {
  const RecipeCostLine({
    this.ingredientDrinkId,
    this.ingredientName = '',
    this.quantity = 0,
    this.unit = '',
    this.unitCost,
    this.packSize,
  });

  /// The stocked drink this line points at, when it is one. Null for an input the
  /// catalogue does not stock (ice, a garnish), which can only be priced by hand.
  final String? ingredientDrinkId;
  final String ingredientName;
  final double quantity;
  final String unit;

  /// The price as paid for ONE purchase unit, overriding the ingredient's own
  /// purchase price.
  final double? unitCost;

  /// How many recipe units one purchase unit covers (a crate of 24 → 24).
  final double? packSize;

  bool get isStocked => ingredientDrinkId != null && ingredientDrinkId!.isNotEmpty;

  /// What to show when the line has no name of its own.
  String get label => ingredientName.isNotEmpty
      ? ingredientName
      : (ingredientDrinkId ?? '');

  factory RecipeCostLine.fromJson(Map<String, dynamic> json) => RecipeCostLine(
        ingredientDrinkId: _asString(json['ingredient_drink_id']),
        ingredientName: (json['ingredient_name'] ?? '').toString(),
        quantity: _asDouble(json['quantity']) ?? 0,
        unit: (json['unit'] ?? '').toString(),
        unitCost: _asDouble(json['unit_cost']),
        packSize: _asDouble(json['pack_size']),
      );

  Map<String, dynamic> toJson() => {
        'ingredient_drink_id': ingredientDrinkId,
        'ingredient_name': ingredientName,
        'quantity': quantity,
        'unit': unit,
        'unit_cost': unitCost,
        'pack_size': packSize,
      };
}

/// The catalogue facts a line is valued against.
class IngredientPrice {
  const IngredientPrice({this.purchasePrice = 0, this.packSize = 1});

  final double purchasePrice;
  final double packSize;

  factory IngredientPrice.fromJson(Map<String, dynamic> json) => IngredientPrice(
        purchasePrice: _asDouble(json['purchase_price']) ?? 0,
        packSize: _asDouble(json['units_per_pack']) ?? 1,
      );
}

/// What a recipe costs and what it earns — one object so the figures on a screen
/// always agree with each other.
class RecipeCosting {
  const RecipeCosting({
    required this.cost,
    required this.complete,
    required this.uncosted,
    required this.sellingPrice,
    required this.hasRecipe,
    this.targetPourCost = RecipeCostHelper.defaultTargetPourCost,
  });

  /// Sum of the ingredients that could be priced.
  final double cost;

  /// False as soon as a line could not be priced, or when there is no recipe.
  final bool complete;

  /// The labels of the lines that could not be priced.
  final List<String> uncosted;

  final double sellingPrice;
  final bool hasRecipe;
  final double targetPourCost;

  static const RecipeCosting empty = RecipeCosting(
    cost: 0,
    complete: false,
    uncosted: [],
    sellingPrice: 0,
    hasRecipe: false,
  );

  double get margin => RecipeCostHelper.marginPerUnit(cost, sellingPrice);

  double get marginPercent => RecipeCostHelper.marginPercent(cost, sellingPrice);

  double get pourCostPercent => RecipeCostHelper.pourCostPercent(cost, sellingPrice);

  /// The price that would hold [targetPourCost]. Null when there is nothing to price.
  double? get targetPrice =>
      RecipeCostHelper.priceForTargetPourCost(cost, targetPourCost);

  /// True when the figures need a caveat on screen.
  bool get hasCaveat => uncosted.isNotEmpty;

  /// A drink nobody can cost yet: no recipe and no purchase price.
  bool get isUnknown => !complete && cost <= 0;

  factory RecipeCosting.fromJson(Map<String, dynamic> json) => RecipeCosting(
        cost: _asDouble(json['cost']) ?? 0,
        complete: json['complete'] == true,
        uncosted: (json['uncosted'] as List<dynamic>? ?? const [])
            .map((entry) => entry.toString())
            .toList(),
        sellingPrice: _asDouble(json['selling_price'] ?? json['sellingPrice']) ?? 0,
        hasRecipe: json['has_recipe'] == true || json['hasRecipe'] == true,
        targetPourCost: _asDouble(json['target_pour_cost']) ??
            RecipeCostHelper.defaultTargetPourCost,
      );
}

/// The rules, all pure. The backend enforces the same ones in
/// utils/recipeCosting.js, so the two never disagree about a margin.
class RecipeCostHelper {
  RecipeCostHelper._();

  /// The pour cost a bar normally aims at, used for the "charge X" hint.
  static const double defaultTargetPourCost = 20;

  /// A cost of 0 (or less) is read as "no cost on record" — a stock row can exist
  /// with a purchase price that was never filled in, and treating that as a real 0
  /// is how a sale ends up looking like a 100 % margin. A *selling* price of 0 is
  /// left alone: giving a unit away is a real thing a shop does.
  static double? positiveOrNull(num? value) {
    if (value == null) return null;
    final parsed = value.toDouble();
    if (parsed.isNaN || parsed <= 0) return null;
    return parsed;
  }

  /// What one recipe unit of [line] costs, or null when no price is on record.
  ///
  /// A price paid for a pack covers [RecipeCostLine.packSize] units, so it is
  /// divided BEFORE it is multiplied by the pour (0.05 × a crate price would be
  /// nonsense). The explicit cost on the line wins over the catalogue.
  static double? lineCost(RecipeCostLine line, IngredientPrice? ingredient) {
    final paid = positiveOrNull(line.unitCost) ??
        positiveOrNull(ingredient?.purchasePrice);
    if (paid == null) return null;

    final pack = positiveOrNull(line.packSize) ??
        positiveOrNull(ingredient?.packSize) ??
        1;
    return (paid / pack) * line.quantity;
  }

  /// Prices a whole recipe. [priceFor] returns the catalogue facts for a stocked
  /// ingredient, or null when it is unknown.
  static RecipeCosting costing({
    required Iterable<RecipeCostLine> lines,
    required double sellingPrice,
    IngredientPrice? Function(String ingredientDrinkId)? priceFor,
    double targetPourCost = defaultTargetPourCost,
  }) {
    final list = lines.toList();
    var cost = 0.0;
    final uncosted = <String>[];

    for (final line in list) {
      if (line.quantity <= 0) {
        // A line with no quantity is a data-entry artefact, not a free ingredient:
        // it is reported like any other line that could not be priced.
        uncosted.add(line.label);
        continue;
      }
      final ingredient =
          line.isStocked && priceFor != null ? priceFor(line.ingredientDrinkId!) : null;
      final amount = lineCost(line, ingredient);
      if (amount == null) {
        uncosted.add(line.label);
        continue;
      }
      cost += amount;
    }

    return RecipeCosting(
      cost: cost,
      // No recipe at all is not "complete": nothing has been costed yet.
      complete: list.isNotEmpty && uncosted.isEmpty,
      uncosted: uncosted,
      sellingPrice: sellingPrice,
      hasRecipe: list.isNotEmpty,
      targetPourCost: targetPourCost,
    );
  }

  /// Cost as a share of the selling price, in percent. 0 when there is no price to
  /// compare against — never NaN, never Infinity.
  static double pourCostPercent(double cost, double sellingPrice) {
    if (sellingPrice <= 0) return 0;
    return (cost / sellingPrice) * 100;
  }

  /// What is left per unit once the ingredients are paid for.
  static double marginPerUnit(double cost, double sellingPrice) =>
      sellingPrice - cost;

  /// Margin on the selling price, in percent. 0 when nothing is charged.
  static double marginPercent(double cost, double sellingPrice) {
    if (sellingPrice <= 0) return 0;
    return (marginPerUnit(cost, sellingPrice) / sellingPrice) * 100;
  }

  /// A usable target pour cost: a percentage above 0 and up to 100, rounded to two
  /// decimals. Null when the value cannot be used.
  ///
  /// This is the SAME rule the backend enforces (utils/recipeCosting.js →
  /// normaliseTargetPourCost), so the app never offers a number the server would
  /// refuse — and a refusal is never quietly replaced by the default, because a
  /// setting that looks saved is worse than an error.
  static double? normaliseTargetPourCost(Object? value) {
    if (value == null) return null;
    final parsed =
        value is num ? value.toDouble() : double.tryParse(value.toString().trim());
    if (parsed == null || parsed.isNaN || parsed <= 0 || parsed > 100) return null;
    return (parsed * 100).round() / 100;
  }

  /// The price that would hold [targetPercent] pour cost — the sellable sentence
  /// ("to keep 20 %, charge X"). Null when there is nothing to price or the target
  /// is not a usable percentage.
  static double? priceForTargetPourCost(double cost, double targetPercent) {
    final spent = positiveOrNull(cost);
    if (spent == null || targetPercent <= 0 || targetPercent > 100) return null;
    return spent / (targetPercent / 100);
  }

  /// Worst pour cost first — the order a manager acts on. Drinks nobody can cost
  /// yet sort last, since a percentage of an unknown cost means nothing.
  static List<MapEntry<String, RecipeCosting>> rankByPourCost(
    Map<String, RecipeCosting> byDrink,
  ) {
    final entries = byDrink.entries.toList()
      ..sort((a, b) {
        if (a.value.isUnknown != b.value.isUnknown) {
          return a.value.isUnknown ? 1 : -1;
        }
        return b.value.pourCostPercent.compareTo(a.value.pourCostPercent);
      });
    return entries;
  }

  /// The shop-wide figures the report header shows.
  ///
  /// Weighted BY UNITS SOLD on purpose: a 45 % pour cost on a drink nobody orders is
  /// not the same problem as one on the best seller, and a plain average would say
  /// they were. Drinks that did not sell contribute nothing.
  static PourCostTotals totals(Iterable<PourCostSample> samples) {
    var units = 0;
    var revenue = 0.0;
    var costOfGoods = 0.0;
    for (final sample in samples) {
      final sold = sample.units > 0 ? sample.units : 0;
      units += sold;
      revenue += sample.sellingPrice * sold;
      costOfGoods += sample.cost * sold;
    }
    return PourCostTotals(
      units: units,
      earned: revenue - costOfGoods,
      revenue: revenue,
      costOfGoods: costOfGoods,
      weightedPourCost: revenue > 0 ? (costOfGoods / revenue) * 100 : 0,
    );
  }
}

/// One drink reduced to what a shop-wide total needs.
class PourCostSample {
  const PourCostSample({
    required this.cost,
    required this.sellingPrice,
    required this.units,
  });

  final double cost;
  final double sellingPrice;
  final int units;
}

/// Ingredients as a share of what the shop took, and what it earned.
class PourCostTotals {
  const PourCostTotals({
    required this.units,
    required this.earned,
    required this.revenue,
    required this.costOfGoods,
    required this.weightedPourCost,
  });

  /// Units sold in the window.
  final int units;

  /// Margin × units: what the window earned once ingredients were paid for.
  final double earned;

  /// What those units were sold for, and what their ingredients cost.
  final double revenue;
  final double costOfGoods;

  /// Ingredients as a share of the money taken. 0 when nothing sold — never NaN.
  final double weightedPourCost;
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

