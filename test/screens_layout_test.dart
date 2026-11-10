// test/screens_layout_test.dart
// LAYOUT SMOKE TEST.
//
// Pumps the app's heaviest screens at phone and tablet sizes and fails if any of
// them reports a *layout* error — the class of bug behind
// "RenderBox was not laid out" (box.dart:2251) which repeats once per frame in
// debug builds and is otherwise very hard to pin down.
//
// Only layout failures are collected: the test environment has no plugins
// (secure storage, TTS, camera) and no network, so other exceptions are expected
// noise and are forwarded to the default handler untouched.
//
// When it fails, the assertion message contains the offending `file:line`
// (extracted by FlutterAssertionGuard) so the culprit is immediately obvious.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drinks_calculator_fixed/providers/auth_provider.dart';
import 'package:drinks_calculator_fixed/providers/drink_provider.dart';
import 'package:drinks_calculator_fixed/providers/inventory_provider.dart';
import 'package:drinks_calculator_fixed/providers/plan_provider.dart';
import 'package:drinks_calculator_fixed/providers/order_provider.dart';
import 'package:drinks_calculator_fixed/providers/customer_provider.dart';
import 'package:drinks_calculator_fixed/providers/shift_provider.dart';
import 'package:drinks_calculator_fixed/providers/recipe_provider.dart';
import 'package:drinks_calculator_fixed/models/recipe_model.dart';
import 'package:drinks_calculator_fixed/utils/recipe_cost_helper.dart';
import 'package:drinks_calculator_fixed/utils/payment_helper.dart';
import 'package:drinks_calculator_fixed/screens/profile_screen.dart';
import 'package:drinks_calculator_fixed/screens/forecast_screen.dart';
import 'package:drinks_calculator_fixed/screens/drink_management_screen.dart';
import 'package:drinks_calculator_fixed/screens/inventory_report_screen.dart';
import 'package:drinks_calculator_fixed/screens/inventory_screen.dart';
import 'package:drinks_calculator_fixed/screens/manager_panel.dart';
import 'package:drinks_calculator_fixed/screens/notifications_screen.dart';
import 'package:drinks_calculator_fixed/screens/subscription_screen.dart';
import 'package:drinks_calculator_fixed/screens/calculator_screen.dart';
import 'package:drinks_calculator_fixed/screens/customer_ledger_screen.dart';
import 'package:drinks_calculator_fixed/screens/manager_dashboard.dart';
import 'package:drinks_calculator_fixed/screens/shift_screen.dart';
import 'package:drinks_calculator_fixed/screens/variance_screen.dart';
import 'package:drinks_calculator_fixed/screens/pour_cost_report_screen.dart';
import 'package:drinks_calculator_fixed/utils/flutter_assertion_guard.dart';
import 'package:drinks_calculator_fixed/widgets/upgrade_required.dart';

void main() {
  final layoutErrors = <String>[];
  late void Function(FlutterErrorDetails) defaultOnError;

  /// Errors that mean "this screen is wired up wrongly" and that a user would see
  /// as console spam:
  ///   * layout failures ("RenderBox was not laid out")
  ///   * provider notifications fired during build
  bool isScreenRenderBug(String text) =>
      FlutterAssertionGuard.isLayoutAssertion(text) ||
      text.contains('called during build') ||
      text.contains('was not laid out');

  setUp(() {
    layoutErrors.clear();
    SharedPreferences.setMockInitialValues({});
    defaultOnError = FlutterError.onError!;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (isScreenRenderBug(text)) {
        final where =
            FlutterAssertionGuard.widgetLocationOf(details) ?? '(unknown widget)';
        layoutErrors.add('  at $where\n  $text');
        return;
      }
      defaultOnError(details);
    };
  });

  tearDown(() {
    FlutterError.onError = defaultOnError;
  });

  /// Pumps [screen] inside a MaterialApp with the providers it reads.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    PlanProvider? plan,
    RecipeProvider? recipes,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          // A plan-gated screen (the reports, for one) renders its upgrade view with
          // the default free plan, so a caller that wants the real screen lays out
          // passes a provider that has been let through.
          ChangeNotifierProvider(create: (_) => plan ?? PlanProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => DrinkProvider()),
          ChangeNotifierProvider(create: (_) => InventoryProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          // Registered in main.dart too — a screen that reads one of these
          // without it in the tree would fail here first.
          ChangeNotifierProvider(create: (_) => CustomerProvider()),
          ChangeNotifierProvider(create: (_) => ShiftProvider()),
          ChangeNotifierProvider(create: (_) => PaymentHelper()),
        // 🍸 Recipe costing: the drink form reads a margin (and opens the recipe
        // editor) for a drink that already exists.
        ChangeNotifierProvider(create: (_) => recipes ?? RecipeProvider()),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    // Let the initial async work settle (it fails gracefully offline).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void expectNoLayoutError() {
    expect(
      layoutErrors,
      isEmpty,
      reason: 'Layout errors detected:\n${layoutErrors.join('\n')}',
    );
  }

  const phone = Size(390, 844);
  const tablet = Size(1100, 900);

  testWidgets('UpgradeRequiredView lays out on phone and tablet',
      (tester) async {
    await pumpScreen(tester, const UpgradeRequiredView(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const UpgradeRequiredView(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('ProfileScreen lays out on phone and tablet (no signed-in user)',
      (tester) async {
    // With no user the screen renders its safe empty state — the point is that it
    // must not throw or overflow while the session is being restored.
    await pumpScreen(tester, const ProfileScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const ProfileScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('SubscriptionScreen lays out on phone and tablet',
      (tester) async {
    await pumpScreen(tester, const SubscriptionScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const SubscriptionScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('SubscriptionScreen gate mode lays out (incl. Continue on Free)',
      (tester) async {
    await pumpScreen(
      tester,
      SubscriptionScreen(gate: true, onContinueFree: () {}),
      size: phone,
    );
    expectNoLayoutError();
    await pumpScreen(
      tester,
      SubscriptionScreen(gate: true, onContinueFree: () {}),
      size: tablet,
    );
    expectNoLayoutError();
  });

  testWidgets('NotificationsScreen lays out on phone and tablet',
      (tester) async {
    await pumpScreen(tester, const NotificationsScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const NotificationsScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('InventoryReportScreen lays out on phone and tablet',
      (tester) async {
    // The screen is plan-gated: with the default free plan this test would only ever
    // lay out the upgrade view, and the tabs — where the money cards live — would
    // never be measured. An admin is let through by the same rule the backend uses.
    final plan = PlanProvider()..setIsAdmin(true);

    await pumpScreen(tester, const InventoryReportScreen(),
        size: phone, plan: plan);
    expectNoLayoutError();

    // The Profit tab: revenue, cost, profit, margin and the two per-unit averages.
    await tester.tap(find.byIcon(Icons.analytics).first);
    await tester.pumpAndSettle();
    expectNoLayoutError();

    await pumpScreen(tester, const InventoryReportScreen(),
        size: tablet, plan: plan);
    expectNoLayoutError();
    await tester.tap(find.byIcon(Icons.analytics).first);
    await tester.pumpAndSettle();
    expectNoLayoutError();
  });

  testWidgets('ForecastScreen lays out on phone and tablet', (tester) async {
    await pumpScreen(tester, const ForecastScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const ForecastScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('PourCostReportScreen lays out on phone and tablet',
      (tester) async {
    // The CARDS are what can overflow on a phone: a long drink name, four figures
    // and a pour cost chip on one 390 px row. A fresh provider per pump, seeded
    // through the provider so the real body is laid out and not just the plan gate
    // (an admin is let through it exactly as the backend's requirePlan does).
    RecipeProvider seeded() => RecipeProvider()
      ..seedReport(
        [
          RecipeCostRow(
            drinkId: '1',
            drinkName: 'Gin tonic maison, double, avec citron vert presse',
            costing: const RecipeCosting(
              cost: 1650,
              complete: true,
              uncosted: [],
              sellingPrice: 3000,
              hasRecipe: true,
            ),
            hasRecipe: true,
            unitsSold: 42,
            profitInWindow: 56700,
          ),
          RecipeCostRow(
            drinkId: '2',
            drinkName: 'Biere 33cl',
            costing: const RecipeCosting(
              cost: 900,
              complete: false,
              uncosted: ['Crate de 24', 'Glace'],
              sellingPrice: 1000,
              hasRecipe: true,
            ),
            hasRecipe: true,
            unitsSold: 3,
            profitInWindow: 300,
          ),
          // Nobody can cost this one: the "-" path and the "no recipe" note.
          const RecipeCostRow(
            drinkId: '3',
            drinkName: 'Cocktail mystere',
            costing: RecipeCosting(
              cost: 0,
              complete: false,
              uncosted: [],
              sellingPrice: 0,
              hasRecipe: false,
            ),
          ),
        ],
        targetPourCost: 22,
      );

    await pumpScreen(
      tester,
      const PourCostReportScreen(),
      size: phone,
      plan: PlanProvider()..setIsAdmin(true),
      recipes: seeded(),
    );
    expectNoLayoutError();
    await pumpScreen(
      tester,
      const PourCostReportScreen(),
      size: tablet,
      plan: PlanProvider()..setIsAdmin(true),
      recipes: seeded(),
    );
    expectNoLayoutError();
  });

  // A JANK GUARD, not a layout one. The report used to spread every card into a plain
  // ListView(children: [...]), which CONSTRUCTS every card widget on every build — a shop
  // with hundreds of drinks paid for all of them up front, and again on every period change.
  // Note that both forms create their ELEMENTS lazily, so counting rendered rows proves
  // nothing; the delegate is what actually distinguishes them.
  testWidgets('PourCostReportScreen constructs its cards lazily', (tester) async {
    final rows = List.generate(
      300,
      (i) => RecipeCostRow(
        drinkId: '$i',
        drinkName: 'Drink $i',
        costing: const RecipeCosting(
          cost: 1000,
          complete: true,
          uncosted: [],
          sellingPrice: 2500,
          hasRecipe: true,
        ),
        hasRecipe: true,
        unitsSold: 300 - i,
        profitInWindow: 45000,
      ),
    );

    await pumpScreen(
      tester,
      const PourCostReportScreen(),
      plan: PlanProvider()..setIsAdmin(true),
      recipes: RecipeProvider()..seedReport(rows),
    );

    // The rows are laid out, so this is not a vacuous pass...
    expect(find.text('Drink 0'), findsOneWidget);
    // ...and the list builds them on demand rather than up front.
    expect(
      tester.widget<ListView>(find.byType(ListView)).childrenDelegate,
      isA<SliverChildBuilderDelegate>(),
      reason: 'ListView(children: [...]) constructs every card widget on each rebuild — '
          'exactly the jank this screen was fixed for',
    );
    expectNoLayoutError();
  });

  testWidgets('InventoryScreen lays out on phone and tablet', (tester) async {
    await pumpScreen(tester, const InventoryScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const InventoryScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('DrinkManagementScreen lays out on phone and tablet',
      (tester) async {
    await pumpScreen(tester, const DrinkManagementScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const DrinkManagementScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('ManagerPanel lays out on phone and tablet', (tester) async {
    await pumpScreen(tester, const ManagerPanel(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const ManagerPanel(), size: tablet);
    expectNoLayoutError();
  });

  // The screens below were the ones the harness missed, which is why
  // "RenderBox was not laid out" could reach the console without a failing test.
  testWidgets('CalculatorScreen lays out on phone and tablet', (tester) async {
    await pumpScreen(tester, const CalculatorScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const CalculatorScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('CustomerLedgerScreen lays out on phone and tablet',
      (tester) async {
    await pumpScreen(tester, const CustomerLedgerScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const CustomerLedgerScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('ShiftScreen lays out on phone and tablet', (tester) async {
    await pumpScreen(tester, const ShiftScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const ShiftScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('VarianceScreen lays out on phone and tablet', (tester) async {
    await pumpScreen(tester, const VarianceScreen(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const VarianceScreen(), size: tablet);
    expectNoLayoutError();
  });

  testWidgets('ManagerDashboard lays out on phone and tablet', (tester) async {
    await pumpScreen(tester, const ManagerDashboard(), size: phone);
    expectNoLayoutError();
    await pumpScreen(tester, const ManagerDashboard(), size: tablet);
    expectNoLayoutError();
  });
}