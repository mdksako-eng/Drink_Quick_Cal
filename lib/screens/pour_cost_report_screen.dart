// screens/pour_cost_report_screen.dart
// Which drink is losing me money: every drink, what it costs to make, what it earns,
// and how much of it actually moved in the window.
//
// WHY THERE IS NO CACHE HERE. A made drink's cost is recomputed from today's
// ingredient prices on every read (drinks-calculator-backend/utils/recipeCosting.js).
// A margin from last week shown as if it were today's is exactly the confident wrong
// number this feature exists to prevent, so with no network the screen says so
// instead of guessing (providers/recipe_provider.dart).
//
// MANAGERS AND PRO ONLY: the backend answers 403 / 402 otherwise (canManageRecipes +
// requirePlan(['pro'])), and this screen mirrors both gates so it never offers a
// figure the server would refuse to produce.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe_model.dart';
import '../providers/plan_provider.dart';
import '../providers/recipe_provider.dart';
import '../theme/app_theme.dart';
import '../utils/drawer_navigation.dart';
import '../utils/helpers.dart';
import '../utils/i18n.dart';
import '../utils/price_extension.dart';
import '../utils/recipe_cost_helper.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/drawer_menu_button.dart';
import '../widgets/recipe_editor_dialog.dart';
import '../widgets/upgrade_required.dart';

class PourCostReportScreen extends StatefulWidget {
  const PourCostReportScreen({super.key});

  @override
  State<PourCostReportScreen> createState() => _PourCostReportScreenState();
}

class _PourCostReportScreenState extends State<PourCostReportScreen> {
  /// The same 7/30/90 choice the shrinkage report offers, so the two reports read
  /// the same way. Days rather than a date picker: a manager asks "this month", not
  /// "the 3rd to the 17th".
  int _days = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final recipes = Provider.of<RecipeProvider>(context, listen: false);
    await recipes.loadReport(from: _fromDate());
  }

  /// The window start as YYYY-MM-DD.
  ///
  /// The upper bound is deliberately NOT sent: the backend then counts everything up
  /// to now, so a sale made during this shift is never dropped by a
  /// midnight-to-midnight boundary.
  String _fromDate() {
    final from = DateTime.now().subtract(Duration(days: _days));
    final month = from.month.toString().padLeft(2, '0');
    final day = from.day.toString().padLeft(2, '0');
    return '${from.year}-$month-$day';
  }

  void _setPeriod(int days) {
    setState(() => _days = days);
    _load();
  }

  /// Lets a manager set the pour cost this shop aims at.
  ///
  /// It is a COMPANY setting, not a device one: the report, the drink card and the
  /// editor all read it, so two devices in one shop must agree. The dialog hands back
  /// the default to mean "clear it", and the backend stores NULL for that.
  Future<void> _editTarget(RecipeProvider recipes) async {
    final controller = TextEditingController(
      text: recipes.targetPourCost.toStringAsFixed(0),
    );
    final chosen = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('recipeTargetPourCost')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: '%'),
            ),
            const SizedBox(height: 10),
            Text(
              t('pourCostTargetHint'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
                dialogContext, RecipeCostHelper.defaultTargetPourCost),
            child: Text(t('pourCostTargetDefault')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () {
              final value =
                  RecipeCostHelper.normaliseTargetPourCost(controller.text);
              if (value == null) {
                // Refused here as well as on the server: a setting that looks saved
                // but is not is worse than an error.
                Helpers.showToast(t('pourCostTargetInvalid'), isError: true);
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: Text(t('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (chosen == null) return;

    final isDefault =
        (chosen - RecipeCostHelper.defaultTargetPourCost).abs() < 0.001;
    final saved = await recipes.setTarget(isDefault ? null : chosen);
    if (!mounted) return;
    if (!saved) {
      Helpers.showToast(t('pourCostTargetFailed'), isError: true);
      return;
    }
    await _load();
  }

  /// Tapping a drink opens its recipe: the answer to "why is this one 40 %?" is one
  /// tap away instead of a trip to the catalogue.
  Future<void> _openRecipe(RecipeCostRow row) => RecipeEditorDialog.show(
        context,
        drinkId: row.drinkId,
        drinkName: row.drinkName,
        sellingPrice: row.costing.sellingPrice,
      );

  @override
  Widget build(BuildContext context) {
    if (!context.read<PlanProvider>().canAccess('recipes')) {
      return const UpgradeRequiredView();
    }
    final theme = Theme.of(context);
    final recipes = context.watch<RecipeProvider>();

    return Scaffold(
      // 🧭 Reachable from every top-level screen: getting from here to another one no
      // longer means going back to the till first.
      drawer: const CustomDrawer(currentScreen: DrawerScreen.pourCost),
      appBar: AppBar(
        // An EXPLICIT leading keeps the back arrow: with a drawer on the Scaffold,
        // Flutter's AppBar would otherwise place its own drawer button here.
        leading: const BackButton(color: Colors.white),
        title: Text(t('pourCostReport')),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: const [DrawerMenuButton(color: Colors.white)],
      ),
      // LAZY WIDGETS, ONE PER DRINK. This used to spread every card into a plain
      // ListView(children: [...]), which allocates EVERY card widget on every build — each
      // one a Card + InkWell + a dozen Texts + its formatted strings. A shop with 200 drinks
      // paid for all 200 before seeing the first, and paid again on every period change and
      // provider notification. Building on demand costs only the rows on screen.
      // (Both forms build their ELEMENTS lazily; the difference is the widget construction.)
      // The pixels are unchanged: the preamble is item 0 and keeps the gap before the first
      // card inside it.
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 1 + (recipes.hasReport ? recipes.report.length : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('pourCostSubtitle'),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 12),
                _periodSelector(),
                const SizedBox(height: 14),
                ..._body(theme, recipes),
              ],
            );
          }
          return _drinkCard(
            theme,
            recipes.report[index - 1],
            recipes.targetPourCost,
          );
        },
      ),
    );
  }

  /// What stands above the drinks: the figures, or the honest reason there are none.
  ///
  /// The drink cards are deliberately NOT in here — the list above builds them lazily.
  List<Widget> _body(ThemeData theme, RecipeProvider recipes) {
    if (recipes.loading && !recipes.hasReport) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (recipes.offline && !recipes.hasReport) {
      return [
        _notice(
          icon: Icons.cloud_off,
          color: Colors.orange,
          text:
              t('offlineBanner').replaceAll('@detail', t('offlineGeneralDetail')),
          onRetry: _load,
        ),
      ];
    }
    if (!recipes.hasReport) {
      return [
        _notice(
          icon: Icons.local_drink_outlined,
          color: Colors.grey,
          text: t('pourCostEmpty'),
        ),
      ];
    }
    return [
      _summaryCard(theme, recipes),
      // The gap before the first card, which now lives in the list rather than here.
      const SizedBox(height: 16),
    ];
  }

  Widget _periodSelector() => SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 7, label: Text('7')),
          ButtonSegment(value: 30, label: Text('30')),
          ButtonSegment(value: 90, label: Text('90')),
        ],
        selected: {_days},
        onSelectionChanged: (selection) => _setPeriod(selection.first),
      );

  /// The shop-wide answer: ingredients as a share of what was taken, weighted by the
  /// units that actually sold, plus what the window earned.
  Widget _summaryCard(ThemeData theme, RecipeProvider recipes) {
    final totals = RecipeCostHelper.totals(
      recipes.report.map(
        (row) => PourCostSample(
          cost: row.costing.cost,
          sellingPrice: row.costing.sellingPrice,
          units: row.unitsSold,
        ),
      ),
    );
    final sold = totals.units > 0;
    final overTarget = sold && totals.weightedPourCost > recipes.targetPourCost;

    return Card(
      elevation: 1,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _metric(
                    t('recipePourCost'),
                    sold
                        ? '${totals.weightedPourCost.toStringAsFixed(1)}%'
                        : '-',
                    color: !sold
                        ? null
                        : (overTarget ? Colors.red[600] : Colors.green[700]),
                  ),
                ),
                Expanded(child: _metric(t('varUnits'), '${totals.units}')),
                Expanded(
                  child: _metric(t('pourCostEarned'), totals.earned.formatted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tapping it sets the shop's own target: the number this whole report is
            // read against, so it must be changeable where it is used.
            InkWell(
              onTap: () => _editTarget(recipes),
              borderRadius: AppRadius.smallAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      overTarget ? Icons.trending_up : Icons.verified_outlined,
                      size: 16,
                      color: overTarget ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${t('recipeTargetPourCost')}: '
                        '${recipes.targetPourCost.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: overTarget ? Colors.orange : Colors.grey[600],
                        ),
                      ),
                    ),
                    Icon(Icons.edit_outlined,
                        size: 14, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      );

  /// One drink: the headline pour cost, the figures behind it, and the caveat when a
  /// price is missing. Worst pour cost first — the order the server sends.
  Widget _drinkCard(ThemeData theme, RecipeCostRow row, double target) {
    final costing = row.costing;
    final unknown = row.isUnknown;
    final over = !unknown && costing.pourCostPercent > target;
    final suggested = costing.targetPrice;

    return Card(
      elevation: 1,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: AppRadius.mediumAll,
        onTap: () => _openRecipe(row),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.drinkName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pourCostChip(costing, over: over, unknown: unknown),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _fact(t('recipeCost'), unknown ? '-' : costing.cost.formatted),
                  _fact(
                    t('recipeMargin'),
                    unknown ? '-' : costing.margin.formatted,
                  ),
                  _fact(t('varUnits'), '${row.unitsSold}'),
                  // Only worth saying when it differs from the price in force.
                  if (suggested != null &&
                      (suggested - costing.sellingPrice).abs() >= 1)
                    _fact(t('recipeSuggestedPrice'), suggested.formatted),
                ],
              ),
              if (costing.hasCaveat) ...[
                const SizedBox(height: 8),
                Text(
                  '${t('recipeUncosted')} ${costing.uncosted.join(', ')}',
                  style: const TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ] else if (unknown) ...[
                const SizedBox(height: 8),
                Text(
                  t('recipeNone'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The headline figure, coloured against the shop's own target rather than a number
  /// chosen here.
  Widget _pourCostChip(
    RecipeCosting costing, {
    required bool over,
    required bool unknown,
  }) {
    final color = unknown ? Colors.grey : (over ? Colors.red : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppAlpha.subtle),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        unknown
            ? t('recipeUncostedShort')
            : '${costing.pourCostPercent.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _fact(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      );

  /// A state with nothing to show, and why — never a blank screen.
  Widget _notice({
    required IconData icon,
    required Color color,
    required String text,
    Future<void> Function()? onRetry,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppAlpha.faint),
          borderRadius: AppRadius.mediumAll,
          border: Border.all(color: color.withValues(alpha: AppAlpha.medium)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 12, color: color)),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: () => onRetry(), child: Text(t('retry'))),
            ],
          ],
        ),
      );
}
