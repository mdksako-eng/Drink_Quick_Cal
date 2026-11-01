// providers/recipe_provider.dart
import 'package:flutter/foundation.dart';

import '../models/recipe_model.dart';
import '../services/supabase_service.dart';
import '../utils/recipe_cost_helper.dart';
import '../utils/staff_permissions.dart';

/// Recipes and pour cost: what a MADE drink costs (a cocktail, a bottle sold by the
/// glass).
///
/// WHY THERE IS NO OFFLINE CACHE HERE. The container ledger caches its list because a
/// shop must be able to see who holds its crates with no network. A margin is the
/// opposite: a cost figure from last week, shown as if it were today's, is exactly
/// the confident wrong number this feature exists to prevent. With no network the
/// screen says so instead of guessing.
///
/// MANAGERS ONLY. The backend answers 403 to anyone else (utils/recipeCosting.js →
/// canManageRecipes); [canManage] mirrors that rule here so the UI never offers an
/// action the server would refuse.
class RecipeProvider extends ChangeNotifier {
  final Map<String, List<RecipeCostLine>> _lines = {};
  final Map<String, RecipeCosting> _costing = {};
  List<RecipeCostRow> _report = const [];
  List<String> _reportUncosted = const [];
  double _targetPourCost = RecipeCostHelper.defaultTargetPourCost;
  bool _loading = false;
  bool _saving = false;
  bool _offline = false;

  /// Every drink, worst pour cost first (server-computed).
  List<RecipeCostRow> get report => _report;

  /// The drinks nobody could cost yet, so the screen can show the caveat instead of
  /// a flattering margin.
  List<String> get reportUncosted => _reportUncosted;

  /// The pour cost the shop aims at, used for the "charge X" hint.
  double get targetPourCost => _targetPourCost;

  bool get loading => _loading;
  bool get saving => _saving;
  bool get offline => _offline;
  bool get hasReport => _report.isNotEmpty;

  /// Whether this role may see a margin or change a recipe.
  static bool canManage(String? role) => StaffPermissions.isManagerRole(role);

  List<RecipeCostLine> linesFor(String drinkId) => _lines[drinkId] ?? const [];

  RecipeCosting? costingFor(String drinkId) => _costing[drinkId];

  /// Loads one drink's recipe, with what it costs at today's ingredient prices.
  /// Answers null when the recipe could not be loaded (offline, or not allowed).
  Future<RecipeCosting?> loadFor(String drinkId) async {
    _loading = true;
    _offline = false;
    notifyListeners();
    try {
      final payload = await SupabaseService.getRecipe(drinkId);
      if (payload == null) {
        _offline = true;
        return null;
      }
      final raw = payload['lines'];
      final lines = raw is List
          ? raw
              .whereType<Map>()
              .map((entry) => RecipeCostLine.fromJson(Map<String, dynamic>.from(entry)))
              .toList()
          : <RecipeCostLine>[];
      _lines[drinkId] = List.unmodifiable(lines);
      final costing = RecipeCosting.fromJson(payload);
      _costing[drinkId] = costing;
      return costing;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Saves a recipe whole — the editor always sends the complete list, because the
  /// backend replaces it in one statement.
  Future<bool> save(String drinkId, List<RecipeCostLine> lines) async {
    _saving = true;
    _offline = false;
    notifyListeners();
    try {
      final result = await SupabaseService.saveRecipe(
        drinkId,
        lines.map((line) => line.toJson()).toList(),
      );
      if (result == null) {
        _offline = true;
        return false;
      }
      _lines[drinkId] = List.unmodifiable(lines);
      return true;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Removes a recipe: the drink goes back to being priced from its own purchase
  /// price.
  Future<bool> remove(String drinkId) async {
    _saving = true;
    _offline = false;
    notifyListeners();
    try {
      final done = await SupabaseService.deleteRecipe(drinkId);
      if (!done) {
        _offline = true;
        return false;
      }
      _lines.remove(drinkId);
      _costing.remove(drinkId);
      return true;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Loads the pour cost report for the window (whole history when no dates).
  Future<bool> loadReport({String? from, String? to}) async {
    _loading = true;
    _offline = false;
    notifyListeners();
    try {
      final payload = await SupabaseService.getRecipeCosting(from: from, to: to);
      if (payload == null) {
        _offline = true;
        return false;
      }
      final rows = payload['rows'];
      _report = rows is List
          ? rows
              .whereType<Map>()
              .map((entry) => RecipeCostRow.fromJson(Map<String, dynamic>.from(entry)))
              .toList()
          : const <RecipeCostRow>[];
      final uncosted = payload['uncosted'];
      _reportUncosted = uncosted is List
          ? uncosted
              .whereType<Map>()
              .map((entry) => (entry['drinkName'] ?? entry['drink_name'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toList()
          : const <String>[];
      final target = payload['targetPourCost'];
      if (target is num && target > 0) _targetPourCost = target.toDouble();
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
