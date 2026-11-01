// widgets/recipe_editor_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/drink_model.dart';
import '../providers/drink_provider.dart';
import '../providers/recipe_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_helper.dart';
import '../utils/helpers.dart';
import '../utils/i18n.dart';
import '../utils/recipe_cost_helper.dart';

/// The recipe editor: what a MADE drink is made of, and what that costs.
///
/// The cost is priced LIVE as the lines are edited, with the same rules the backend
/// applies (utils/recipe_cost_helper.dart ↔ utils/recipeCosting.js), so a manager
/// watches the margin move while deciding a pour instead of saving first and finding
/// out afterwards.
///
/// A line whose price is unknown is called out rather than counted as free: that is
/// the whole difference between a real margin and a flattering one.
class RecipeEditorDialog extends StatefulWidget {
  const RecipeEditorDialog({
    super.key,
    required this.drinkId,
    required this.drinkName,
    required this.sellingPrice,
  });

  final String drinkId;
  final String drinkName;
  final double sellingPrice;

  /// Opens the editor for one drink.
  static Future<void> show(
    BuildContext context, {
    required String drinkId,
    required String drinkName,
    required double sellingPrice,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => RecipeEditorDialog(
        drinkId: drinkId,
        drinkName: drinkName,
        sellingPrice: sellingPrice,
      ),
    );
  }

  @override
  State<RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends State<RecipeEditorDialog> {
  final List<_LineDraft> _drafts = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // The recipe comes from the backend, so the first frame shows a spinner rather
    // than an empty recipe that looks like "no ingredients".
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    await provider.loadFor(widget.drinkId);
    if (!mounted) return;
    setState(() {
      for (final draft in _drafts) {
        draft.dispose();
      }
      _drafts
        ..clear()
        ..addAll(provider.linesFor(widget.drinkId).map(_LineDraft.fromLine));
      // One empty row so the editor is usable immediately.
      if (_drafts.isEmpty) _drafts.add(_LineDraft.empty());
      _loaded = true;
    });
  }

  /// The catalogue, as the prices a line is valued against.
  Map<String, IngredientPrice> _priceIndex() {
    final drinks = Provider.of<DrinkProvider>(context, listen: false).allDrinks;
    return {
      for (final drink in drinks)
        drink.id: IngredientPrice(
          purchasePrice: drink.purchasePrice,
          packSize: drink.unitsPerPack <= 0 ? 1 : drink.unitsPerPack.toDouble(),
        ),
    };
  }

  RecipeCosting _preview() {
    final prices = _priceIndex();
    return RecipeCostHelper.costing(
      lines: _drafts.map((draft) => draft.toLine()).toList(),
      sellingPrice: widget.sellingPrice,
      priceFor: (id) => prices[id],
    );
  }

  Future<void> _save() async {
    final lines = _drafts.map((draft) => draft.toLine()).toList();

    // The same checks the backend makes, so a mistake shows up here instead of as a
    // 400 after a round trip.
    for (final line in lines) {
      if (line.quantity <= 0) {
        Helpers.showToast(t('recipeNeedsQuantity'), isError: true);
        return;
      }
      if (!line.isStocked && line.ingredientName.trim().isEmpty) {
        Helpers.showToast(t('recipeNeedsName'), isError: true);
        return;
      }
    }

    final provider = Provider.of<RecipeProvider>(context, listen: false);
    final ok = await provider.save(widget.drinkId, lines);
    if (!mounted) return;
    if (!ok) {
      Helpers.showToast(t('recipeSaveFailed'), isError: true);
      return;
    }
    Helpers.showToast(t('recipeSaved'));
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    final ok = await provider.remove(widget.drinkId);
    if (!mounted) return;
    if (!ok) {
      Helpers.showToast(t('recipeSaveFailed'), isError: true);
      return;
    }
    Helpers.showToast(t('recipeDeleted'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<RecipeProvider>(context);
    final drinks = Provider.of<DrinkProvider>(context).allDrinks;
    final costing = _loaded ? _preview() : RecipeCosting.empty;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('recipeForDrink')),
          Text(
            widget.drinkName,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: !_loaded
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSummary(costing, theme),
                    const SizedBox(height: 16),
                    ..._drafts.asMap().entries.map(
                          (entry) =>
                              _buildLine(entry.key, entry.value, drinks, theme),
                        ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _drafts.add(_LineDraft.empty())),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(t('recipeAddIngredient')),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        if (_loaded && provider.linesFor(widget.drinkId).isNotEmpty)
          TextButton(
            onPressed: provider.saving ? null : _remove,
            child: Text(
              t('recipeRemove'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('cancel')),
        ),
        ElevatedButton(
          onPressed: provider.saving ? null : _save,
          child: provider.saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t('save')),
        ),
      ],
    );
  }

  /// The live figures. Everything is priced locally with the same rules the backend
  /// uses, so what the manager sees while typing is what will be stored.
  Widget _buildSummary(RecipeCosting costing, ThemeData theme) {
    final target = costing.targetPrice;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: AppAlpha.subtle),
        borderRadius: AppRadius.smallAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(t('recipeCost'), CurrencyHelper.format(costing.cost)),
          _summaryRow(t('recipeMargin'), CurrencyHelper.format(costing.margin)),
          _summaryRow(
            t('recipePourCost'),
            '${costing.pourCostPercent.toStringAsFixed(1)}%',
          ),
          if (target != null)
            _summaryRow(
              '${t('recipeSuggestedPrice')} (${costing.targetPourCost.toStringAsFixed(0)}%)',
              CurrencyHelper.format(target),
            ),
          if (costing.hasCaveat) ...[
            const SizedBox(height: 6),
            Text(
              '${t('recipeUncosted')} ${costing.uncosted.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );

  Widget _buildLine(
    int index,
    _LineDraft draft,
    List<Drink> drinks,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: AppRadius.smallAll,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: draft.ingredientDrinkId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t('recipeIngredient'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(t('recipeNotStocked')),
                    ),
                    ...drinks.map(
                      (drink) => DropdownMenuItem<String?>(
                        value: drink.id,
                        child: Text(drink.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => draft.setIngredient(value, drinks)),
                ),
              ),
              IconButton(
                tooltip: t('recipeRemove'),
                onPressed: _drafts.length <= 1
                    ? null
                    : () => setState(() => _drafts.removeAt(index)),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t('recipeQuantity'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.unitCost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t('recipeUnitCost'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          // An input the catalogue does not stock (ice, a garnish) has no purchase
          // price to inherit, so it needs a name and a cost of its own.
          if (!draft.isStocked) ...[
            const SizedBox(height: 8),
            TextField(
              controller: draft.name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t('recipeIngredient'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One editable line. Kept as controllers so typing never rebuilds the list from
/// scratch, which would move the caret.
class _LineDraft {
  _LineDraft({
    this.ingredientDrinkId,
    String name = '',
    String quantity = '',
    String unit = '',
    String unitCost = '',
    this.packSize,
  })  : name = TextEditingController(text: name),
        quantity = TextEditingController(text: quantity),
        unitCost = TextEditingController(text: unitCost),
        _unit = unit;

  factory _LineDraft.empty() => _LineDraft();

  factory _LineDraft.fromLine(RecipeCostLine line) => _LineDraft(
        ingredientDrinkId: line.ingredientDrinkId,
        name: line.ingredientName,
        quantity: line.quantity > 0 ? _trimNumber(line.quantity) : '',
        unit: line.unit,
        unitCost: line.unitCost != null ? _trimNumber(line.unitCost!) : '',
        packSize: line.packSize,
      );

  String? ingredientDrinkId;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitCost;
  String _unit;
  double? packSize;

  bool get isStocked =>
      ingredientDrinkId != null && ingredientDrinkId!.isNotEmpty;

  /// Picking a drink also fills its name and unit, so the saved line still reads
  /// correctly if the ingredient is renamed later.
  void setIngredient(String? drinkId, List<Drink> drinks) {
    ingredientDrinkId = drinkId;
    if (drinkId == null) return;
    for (final drink in drinks) {
      if (drink.id == drinkId) {
        name.text = drink.name;
        _unit = drink.unit;
        packSize = drink.unitsPerPack > 0 ? drink.unitsPerPack.toDouble() : 1;
        return;
      }
    }
  }

  RecipeCostLine toLine() => RecipeCostLine(
        ingredientDrinkId: ingredientDrinkId,
        ingredientName: name.text.trim(),
        // A comma is how a French keyboard types a decimal point.
        quantity: double.tryParse(quantity.text.trim().replaceAll(',', '.')) ?? 0,
        unit: _unit,
        unitCost: double.tryParse(unitCost.text.trim().replaceAll(',', '.')),
        packSize: packSize,
      );

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitCost.dispose();
  }
}

/// 0.050 → "0.05", 1.000 → "1": a number a person would have typed.
String _trimNumber(double value) {
  final text = value.toStringAsFixed(3);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}



