# Active context

_Updated: 2026-11-01_

## Recipe follow-ons: report screen, Phase B stock, per-shop target (2026-11-01)
- **`e90619b`** — the pour cost report screen (`lib/screens/pour_cost_report_screen.dart`, drawer Reports
  group, `canAccess('recipes')`): shop-wide pour cost weighted by units sold, units + margin earned, every
  drink worst-first, the caveat when a price is missing, tap a drink to open its recipe.
  `RecipeCostHelper.totals` is pure and tested; the layout harness seeds a report via
  `RecipeProvider.seedReport` (a new `recipes:` hook in `pumpScreen`) so the CARDS lay out, not only the gate.
- **`4d26cca`** — Phase B: a sale takes the recipe's **whole units** off the shelf (`utils/recipeStock.js`
  pure, 9 Jest tests; `moveIngredientsForSale` inside `POST /inventory/sell`). **Whole units only,
  deliberately**: `inventory.quantity` is an int everywhere, so a fractional pour is REPORTED
  (`notTracked`) and never written. Best-effort: a completed sale never fails on a recipe. Ledger reason
  `'recipe'` is neither a sale nor a loss (`VarianceHelper.consumptionReasons`) — changing that
  classification breaks the loss rate or the shrinkage list.
- **`9bd63e7`** — per-shop target pour cost: `companies.target_pour_cost` (boot `ALTER`, NULL = the built-in
  default), `PATCH /recipes/target` (manager + Pro), refused with 400 when unusable rather than silently
  defaulted. The report, the drink card and the editor all read it.
- Gates: backend **49 suites / 655 tests**, Flutter **522**, `flutter analyze lib` **0 errors**, i18n
  **EN=1524 FR=1524**.
- **Owner action**: the `target_pour_cost` column arrives with the next **manual** Render deploy; until then
  the report falls back to 20 % (the read is best-effort).

## Recipe table in production: present — and the deploy question (2026-11-01)
- **This corrects the entry that stood here**: it claimed `drink_recipes` "has never been applied" and
  that recipe routes would 500. That was **not proven**. The probe behind it read PostgREST's
  `404 PGRST205`, and a control query (`/rest/v1/zzz_not_a_real_table`) returns the *same* code:
  PGRST205 only means "not in PostgREST's schema cache" — true both for a table that does not exist and
  for one created minutes earlier. **Read the body's `code`/`message`, never the status alone.**
- **Re-probed 19:04 UTC**: `/rest/v1/drink_recipes` -> `401 42501 permission denied for table
  drink_recipes`; `/rest/v1/drinks` answers 42501 as well. So the table exists and anon/authenticated
  are revoked — the state the boot routine and `sql/rls_recipes.sql` both produce.
- **The deploy landed — which falsifies how this bullet first read.** The marker push (`9e9c4de`) went
  out at `18:52:09Z` and was live at `19:13:55Z`: **21m46s later**, well past the 17-minute window that
  was polled. A short poll proves nothing either way — that is exactly the mistake made here. The
  2026-10-29 entry further down records that deploys here are MANUAL, and a click landing ~2 min later
  fits that (a 22-minute "build queue" does not). So the likeliest trigger is the owner clicking Manual
  Deploy; Render's Deploys list names the trigger for certain. Never assume a push deploys. Live host:
  `https://drink-quick-cal-kja1.onrender.com` (DEPLOY.md's `drink-quic-cal-kj1` was a typo that 404s on
  every path — fixed there).
- **Production now runs the newest commit**, so the Phase 18 recipe routes ARE deployed: the marker
  commit is a descendant of the recipe commit, which proves the routes exist in the running image.
  No unauthenticated probe can show that on its own — the data router authenticates at router level,
  so `/api/data/zzz_nonsense` answers 401 exactly like `/api/data/recipes/costing`.
- Also stale, now corrected in DEPLOY.md: "still running the OLD code (plaintext, open /users)".
  `/api/ping` -> `pong` and `/api/users` -> 401.
- Commit state: Phase 18 had been left uncommitted and is now `04a6b03` (pickers `2be7d64`, rules +
  memory bank + editor config `5d486bc`, guide PDF `d3c439c`).

## CamerPay setup guide: a generated PDF, not a hand-made one (2026-11-01)
- **`docs/CamerPay-Setup-Guide.pdf`** (5 pages) is what a shop hands to whoever configures its
  CamerPay account. It is BUILT, not written: the source of truth is
  `scripts/generate_campay_guide.dart`, rebuild with `dart run scripts/generate_campay_guide.dart`
  from the repo root. Never hand-edit the PDF — edit the script and regenerate.
- It uses the `pdf` package the app already depends on (no new dependency) and the built-in
  Helvetica/Courier fonts, so it needs no network and no font files. **Keep the text inside Latin-1**
  (no emoji, no arrows, no typographic quotes) or the generator throws — the French dashboard labels
  ("Tokens d'acces") do use their accents, which Latin-1 covers.
- Content is grounded in the code, not in guesswork: `utils/campay.js`,
  `routes/payment.routes.js`, `utils/companyPaymentCredentials.js` and CamerPay's own docs
  (camerpay.biz/docs). It covers the token (`/client/api`), the webhook URL (dashboard "Webhook
  Configuration" > "Callback URL"), the Secret HMAC, the blockers, going live, the till flow and a
  troubleshooting table.
- Verified after generating: `%PDF-1.5`, `/Count 5`, ends with `%%EOF`, and the content streams
  decompress to real text (PowerShell: Latin1 + DeflateStream on each `stream` block).
- **Open**: `DEPLOY.md` does not point at this guide yet; the guide is English only (a French twin
  would need a second generator pass).

## Searchable pickers: the "choose a customer" dialog no longer chokes (2026-11-01)
- **The problem**: every "choose an existing …" dialog listed ALL of them in a fixed-height box with no
  search. The till's customer dialog showed every approved account in a 180 px window, and the
  purchase-order drink picker was a `SimpleDialog` of the whole catalogue. Fine with ten items, unusable
  with three hundred — and the operator's workaround was to type a walk-in name, which is exactly how a tab
  ends up with no account behind it.
- **One shared widget**: `widgets/searchable_picker_list.dart` (`SearchablePickerList<T>`) — a search box, a
  caller-supplied `matches` predicate, and a "nothing matches" line. `maxHeight: null` when the parent
  already scrolls (screens/tabs), a number when it sits inside a dialog.
- **One shared rule**: `utils/text_search.dart` (`TextSearch.fold` / `digitsOnly` / `textMatches`) — case-
  and accent-insensitive ("emile" finds "Émile"), and numbers match on digits so "6 77 12 34 56" finds
  "+237 677123456" and a formatted barcode still scans. `CustomerLedgerHelper.fold/textMatches/
  normalizePhone` are now thin wrappers over it, so existing call sites and tests are untouched.
- **Wired into four places**: the till's customer dialog (name / customer number / phone / address), the
  Customers tab, the containers "who holds" list (name / number), and the purchase-order drink picker
  (name / barcode).
- **Dialog height budget**: the till dialog's list went 180 → 140 px because the search box costs ~60 px and
  an AlertDialog's content does NOT scroll. Do not raise it without first making the content scrollable.
- Gates: Flutter **511 tests** (+13), `flutter analyze lib` **489 issues / 0 errors**, i18n **EN=1518 FR=1518**.
- **Found while reading, NOT fixed**: the containers screen can only record a movement for a customer who
  ALREADY holds something (the backend's `orderByOutstanding` drops zero rows), so a customer can never be
  handed their first crate. Fixing it means a "hand out" action that picks ANY approved customer — a
  product decision, not a bug fix to slip in.

## Recipe / pour cost (Phase 18) — shipped, costing-only (2026-11-01)
- **What landed**: `drink_recipes` (new table, RLS + REVOKE at boot and `sql/rls_recipes.sql`) + pure
  `utils/recipeCosting.js` (22 Jest tests) + 5 routes in `routes/data.routes.js` (manager-only,
  `requirePlan(['pro'])`) + the Flutter half (`utils/recipe_cost_helper.dart` 13 tests, `models/recipe_model.dart`,
  `providers/recipe_provider.dart`, `widgets/recipe_editor_dialog.dart`, entry point in the drink form).
- **The load-bearing decision**: the cost is **computed on every read and never stored**, from the ingredients'
  current `drinks.purchase_price`. One supplier price change moves every margin at once and no row can disagree
  with its own history. Nested recipes (a pre-mix) resolve with a cycle guard and a depth cap.
- **The second decision**: an unpriced line is never read as a free ingredient. It is left out and counted
  (`complete: false`) and the UI shows the caveat — the same discipline as the Reports profit fix. **Keep this
  if you extend it.**
- **Phase A boundary**: a recipe does NOT move stock. Selling a cocktail still deducts the cocktail, so variance
  and the Z-report are untouched. A `schema_hardening` test asserts no recipe route touches `inventory`.
  Ingredient deduction is Phase B, deliberately.
- **Free fix that came out of it**: receiving a delivery now writes `drinks.purchase_price` (it never did), so
  the cost actually paid stops going stale — that also feeds the Reports "average purchase price" card.
- Gates: backend **643 tests** / 48 suites, Flutter **498 tests**, `flutter analyze lib` **489 issues / 0 errors**,
  i18n **EN=1515 FR=1515**.
- **Next for this feature**: a screen for `GET /recipes/costing` (the endpoint is served, parsed into
  `RecipeProvider.report`, and nothing renders it yet) — that is the "which drink is losing me money" list.
  Then Phase B, then a per-company target pour cost (the 20 % default is hard-coded in both
  `utils/recipeCosting.js` and `utils/recipe_cost_helper.dart` and must stay in step).

## Shadow/gradient pass: measured, and deliberately not swept (2026-10-31)
- **The till's background gradient now uses `AppBrand.surface(primaryColor)`** — the one true "surface"
  gradient in the app, so the till and the drawer header read as the same surface. Dark mode keeps its neutral
  grey on purpose.
- **Everything else in those two categories is semantic, not decorative**: 19 `BoxShadow(` sites include the
  sync indicator's *status-coloured* glow, the AI button's purple pulse and the auth screen's orange warning.
  Mapping them to neutral `AppShadow.soft`/`raised` would delete the meaning. The remaining depth shadows are
  also *crisper* (blur 4–10, offset 0,1–0,2) than either token level (blur 16/28), so forcing them would make
  every card fuzzier — a redesign no test can see.
- **Fixed instead: 53 deprecated `withOpacity` calls** (the earlier alpha sweep only matched `withValues`).
  Renamed to `withValues(alpha:)` and 46 moved onto `AppAlpha` steps → `flutter analyze lib` **534 → 481**.
- Gates: Flutter **485 tests**, `flutter analyze lib` **481 issues** / 0 errors.
- **Conclusion**: no further token work is pending. What is left is intentional.

## Per-screen cleanup done: 533 values onto the tokens (2026-10-31)
- **533 replacements / 43 files**: 339 exact (no pixel change) + 194 snapped to the nearest step, reported by
  count. Radii (8/12/16 exact, plus a new `AppRadius.xlarge = 20` because 20 was used 53× — more than `small`)
  and overlay alphas (0.1/0.2/0.06 → `AppAlpha.subtle`/`medium`/`faint`).
- **`AppRadius` getters are now `const` fields** — `BorderRadius.all` is a const constructor, so tokens work
  inside `const` widgets. That is what made a scripted migration possible at all.
- **Deliberately left literal**: alphas > 0.32 (40 sites — compositional opacity, e.g. the lock screen's
  translucent gradient that the glass reads through) and box shadows/gradients (36/27 — 17 distinct blur
  values, no dominant pattern, one semantic orange glow). Snapping those would redesign every raised surface
  and no test can see it; it needs a visual pass, screen by screen.
- **Guards** in `test/app_theme_test.dart` (20 tests): no `BorderRadius.circular(8|12|16|20)` (excluding
  `pw.BorderRadius`) and no `withValues(alpha: 0.06|0.1|0.2)` may reappear under `lib/`.
- **Trap for next time**: a literal `BorderRadius.circular(N)` replacement also hits the **`pdf` package's**
  `pw.BorderRadius.circular(N)` — 7 sites were left with a dangling `pw.` prefix and had to be restored.
- Gates: Flutter **485 tests**, `flutter analyze lib` **534 issues** / 0 errors.

## The chosen style is applied app-wide now (2026-10-31)
- **The decision was 2026-10-29, the application was only the drawer.** `app_theme.dart` was imported by three
  files; every other screen hand-picked its own radii/alphas/shadows. The theme builders in `main.dart` now
  consume the tokens (`AppRadius.mediumAll` / `largeAll`, `AppElevation.raised` / `floating`) and the missing
  surfaces got a rule: `dialogTheme`, `bottomSheetTheme`, `snackBarTheme`, `filledButtonTheme`,
  `textButtonTheme`. New token class `AppElevation` (flat 0 / soft 2 / raised 4 / floating 8).
- **One glass surface, on purpose**: `AppGlass` (blur 12 + tint + hairline) is applied to the **lock overlay**,
  the only surface whose backdrop cannot move. It is applied in the overlay (not the lock screen's body) so
  the blur lands on the frozen app behind it. **Rule, enforced by two tests**: no file under `lib/screens/`
  may reference `AppGlass`, and it may be applied exactly once — `BackdropFilter` re-blurs every frame, so
  glass behind a scrolling list would cost a low-end phone its frame budget.
- Gates: Flutter **483 tests**, `flutter analyze lib` **534 issues** / 0 errors.
- **Still open**: the per-screen cleanup (36 `BoxShadow`, 27 `LinearGradient`, ~197 `withValues(alpha:)` in
  screens older than the tokens).

## Reports: the margin is real now, and the "general" prices exist (2026-10-31)
- The Profit tab of `inventory_report_screen.dart` priced history with **today's** catalogue prices and fell
  back to a **zero object** when a drink had left the catalogue or had no stock row — so a sale could read as
  0 revenue / 0 cost and show a **100 % margin**. It now prices from the ledger (`sellingPriceAtSale` /
  `purchasePriceAtSale`) through `lib/utils/report_profit_helper.dart` (pure, 12 tests), falls back to the
  catalogue only for legacy movements, and reads a cost of 0 as "not on record" rather than inventing one.
- **Added**: average selling price and average purchase price **per unit sold** in the period, plus an amber
  caveat when some units had no cost on record or could not be valued. Keys `rpt_avgSellingPrice`,
  `rpt_avgPurchasePrice`, `rpt_perUnitSold`, `rpt_caveatNoCost`, `rpt_caveatUnvalued` (EN+FR).
- **Found on the way**: `test/screens_layout_test.dart` never actually laid this screen out — the harness
  injects a free plan, so it measured the upgrade view. `pumpScreen` now takes an optional `PlanProvider`, and
  measuring the real tabs immediately exposed a **100 px RenderFlex overflow** in the date-range card (an
  unbounded `Column` in a `Row`), now fixed with `Expanded`.
- **The export carries the money too (same day)**: `InventoryReportFiles.profitRows` is the single definition
  the Excel `Profit` sheet and the CSV block both consume; numbers stay numeric so spreadsheets can sum them;
  the PDF takes an optional `currencySymbol`; and the caveats (no cost on record / could not be valued) are
  printed in all three formats. The screen passes its own summary in, so file and screen are one calculation.
  New keys `exp_profitSection` / `exp_unitsSold`; the dialog gained a "Profit & margins" checkbox, appended
  last so the existing checkbox order stays stable.
- Gates: Flutter **476 tests**, `flutter analyze lib` **534 issues** / 0 errors, i18n **EN=1484 FR=1484**.

## The drawer now reaches every top-level screen (2026-10-31)
- The drawer was **hub-only** (`calculator_screen.dart` was its single mount point), so moving between two
  back-office screens meant a trip back to the till. The operational screens now carry it themselves.
- **17 screens carry it**: inventory, drinks, shift, customers, containers, purchasing, analytics, forecast,
  variance, staff, approvals, settings, profile, subscription, AI assistant, admin panel, report-a-problem.
  The till keeps its own drawer (its `currentScreen` defaults to `DrawerScreen.dashboard`).
- **Not mounted on purpose**: the barcode scanner (focused camera task); `invoices` / `about` / `help` are
  callbacks on the till, not screens; sub-screens that are not drawer destinations (inventory report, admin
  support reports, notifications) are untouched so the menu never offers a way to somewhere the user did not
  come from. Subscription is conditional: from the drawer it gets the drawer + a pinned back arrow, as a
  paywall gate (`widget.gate`) it stays a modal detour with neither.
- Two traps, both now documented in the code so they cannot come back:
  1. `Scaffold.of(context)` inside `appBar:` resolves **above** the Scaffold → `DrawerMenuButton`
     (`lib/widgets/drawer_menu_button.dart`) is a widget so its own context sits below it.
  2. A Scaffold `drawer` **replaces the implied back arrow** with a hamburger
     (`if (hasDrawer) leading = DrawerButton()` runs before the dismissal branch). Only an **explicit**
     `leading: BackButton()` keeps the arrow; the drawer opens from the menu button in `actions`.
- `test/drawer_menu_button_test.dart` pins both invariants — it failed on its first run, which is how (2) was
  found. Flutter **456 tests**, `flutter analyze lib` 535 issues / 0 errors, i18n EN=1477 FR=1477.

## Payment-column drops: checked against the LIVE database (2026-10-31)
- **`sql/drop_dead_payment_columns.sql` is DONE — the owner ran it.** Probed live through PostgREST with the
  publishable key (read-only, no credentials opened): `mtn_api_key`, `mtn_secret_key`, `mtn_merchant_id`,
  `orange_api_key`, `orange_secret_key`, `orange_merchant_phone` all answer SQLSTATE **`42703`** ("column does
  not exist"), while the kept controls `mtn_enabled` / `campay_enabled` answer **`42501`** (exists; `anon` has
  no SELECT on `companies`). So **no plaintext MTN/Orange credential is left in `public.companies`**, and the
  earlier "still sitting in the schema" note was stale.
- **Still outstanding: `sql/drop_notchpay_columns.sql`.** `notchpay_private_key`, `notchpay_public_key`,
  `notchpay_sync_id` and `notchpay_webhook_hash` are all still present (`42501`). Safe to run: the only
  `notchpay` mentions left in the backend are the explanatory comments at `server.js:213-215`, and the
  `mtn_api_key` / `orange_api_key` names still in `routes/subscriptions.js` are `process.env.PLATFORM_*`
  keys for the platform's own Momo rail — not company columns, so they are unaffected by the drop.
- Backend was live and healthy at the time of the check: `release 2026-10-29-credential-hardening`,
  `database CONNECTED`, 14 users (the one 503 seen was a cold start; a retry answered 200).
- **Probe technique** (works without the Supabase MCP or CLI — handy for the next schema question):
  `curl.exe -s -H "apikey: <publishable key>" ".../rest/v1/companies?select=<column>&limit=1"`.
  `42703` = the column is gone; `42501` = the column exists.

## Purchasing backend shipped (Phase 16, `34949f1`) 🟡 app side pending
- **The gap**: the forecast already recommends what to reorder, but nothing could turn that into an
  order and nothing remembered what a supplier charges — the project's own notes said
  "supplier prices are not stored yet". This is the biggest remaining eLeader gap and the one that
  unlocks wholesalers.
- **Schema**: `suppliers`, `purchase_orders`, `purchase_order_lines` — created at boot with RLS +
  `REVOKE` on all three, plus `sql/rls_purchasing.sql` and 3 guard tests.
- **Routes**: `GET/POST /suppliers`, `GET/POST /purchase-orders`, `PATCH /purchase-orders/:id`
  (send/cancel), `POST /purchase-orders/:id/receive`.
- **Who decides what**: a manager commits the shop's money (create / send / cancel); ANY staff member
  may **receive** a delivery, because that is a physical fact at the door like a restock. Rules are
  pure and unit tested (`utils/purchasing.js`, 15 tests).
- **Receiving reuses the guarded path**: `applyStockDelta`, so it can never drive a shelf negative and
  it writes the movement with `reason: 'purchase_order'` and the PO reference as `order_id`. One
  refusal stops the whole delivery and leaves the order `sent` so it can be received again — instead
  of half of it landing and half vanishing. A reference is generated from the row id (`PO-000123`) so
  two orders can never share one, and the supplier is validated against the company, never trusted
  from the body.
- **App side shipped (`97b1f88`)**: `ApiConfig` endpoints, `PurchasingProvider`, a **Purchasing** drawer
  entry (every non-customer role) with suppliers (managers) and orders that move draft → sent →
  received. A manager creates/sends (supplier chips + lines from the catalogue, unit cost prefilled
  from what the shop last paid); any staff member may receive, confirmed first because it puts stock
  on the shelf and the order becomes terminal. A refusal is reported as a refusal, never as success.
- **The loop is closed (`a0220d1`)**: the forecast screen offers a manager **"Order what is
  recommended"** — each recommended quantity becomes a purchase-order line and the new-order dialog
  opens filled in (pick the supplier → create → send → receive → stock back on the shelf). Every line
  is resolved to the REAL catalogue drink by name (`InvoiceImportHelper.findCatalogDrink`) because
  receiving needs a drink id; a name that has left the catalogue stops the action and names the drink
  rather than inventing or dropping a line. Unit cost is prefilled with what the shop last paid.
- Gates: backend **43 suites / 592 tests**; `flutter analyze lib` 0 errors; i18n **EN=1479 FR=1479**;
  Flutter **426 tests**.

## Subscription expiry drift fixed (`73b8045`) ✅
- **The bug**: `GET /subscriptions/status` auto-expired the **company** only
  (`routes/subscriptions.js:131-140`), so its `subscriptions` rows kept saying `active` for ever while
  the company read `free`/`expired`. The app reads the company row, so a stale `active` subscription
  granted nothing — that is what made "why is Banga School still Free after paying" confusing.
- **The fix**: the sweep now marks the company's **live** subscription rows expired in the same step,
  via `utils/subscriptionExpiry.js` (+6 tests). Only `active` rows are swept: a `pending` attempt may
  still be confirmed by a late webhook, and expiring it would turn that confirmation into a no-op and
  **silently swallow the payment**. The check is case/space tolerant on purpose — a stray `' Active '`
  must not survive the very sweep meant to clean it.
- **Correction to an earlier report**: the 5 stale `active` rows are now *consistent* — they belong to
  company #42, which was comped to pro/active, so they finally agree with their company. A cleanup
  `UPDATE` for production would therefore match **0 rows**; nothing to run.
- **Still a symptom worth chasing**: 33 `pending` subscriptions belong to companies that are already
  active (plus 1 for a company with no plan) — attempts that started and never confirmed. Needs one
  live CamerPay test on the current build.
- Gates: backend **42 suites / 574 tests**.

## Registered customers at the till + part-payment plumbing ✅
- **Bug (user-reported)**: "when customer is about to pay the register customer do not show in the
  customer information". Cause: `calculator_screen.dart` read `CustomerProvider.approved` but
  **never loaded the provider** — only `customer_ledger_screen.dart:41` ever called `load()`, so the
  list was empty unless the operator had opened the Customers screen first in that session. Fixed by
  loading on demand (new `CustomerProvider.hasLoaded`); the dialog now shows the registered
  **identity** (customer number + phone), not just a name and a phone.
- **Part-payment plumbing (backend)**: `utils/orderPayment.js` + 14 tests. A sale may be paid in
  full, overpaid (change), or part-paid with the rest on a tab. `POST /orders` now refuses an
  inconsistent split (the Z-report derives `collected = Σ amount_paid`, `on_credit = sales −
  collected` from these numbers) and requires a real account of the company when a tab is left. New
  idempotent column `orders.tab_amount` — deliberately NOT `orders.balance`, which means "change
  handed back" for a cash sale.
- **Till side shipped (`2d6edad`)**: the operator can take part of the money and put the rest on a
  registered customer's tab. The account is picked in the customer information, the order carries
  `amount_paid` + `tab_amount` + `customer_id`, and the remainder is written to the credit ledger as a
  charge linked by `order_id`. The manager's credit limit is checked BEFORE anything is written (the
  server re-checks it), and a failed ledger write is reported plainly instead of a clean success. No
  invoice change was needed: a negative balance already renders as "Balance due" in red with a Pending
  status.
- Gates: backend **41 suites / 568 tests**; `flutter analyze lib` 0 errors; Flutter **426 tests**.

## Registered customers now show at the till + part-payment plumbing ✅
- **Bug (user-reported)**: "when customer is about to pay the register customer do not show in the
  customer information". Cause: `calculator_screen.dart` read `CustomerProvider.approved` but
  **never loaded the provider** — only `customer_ledger_screen.dart:41` ever called `load()`, so the
  list was empty unless the operator had opened the Customers screen first in that session. Fixed by
  loading once on demand (new `CustomerProvider.hasLoaded`), and the dialog now shows the registered
  **identity** (customer number + phone), not just a name and a phone.
- **Part-payment plumbing (backend)**: `utils/orderPayment.js` + 14 tests — a sale may be paid in
  full, overpaid (change), or part-paid with the rest on a tab. `POST /orders` now refuses an
  inconsistent split (the Z-report derives `collected = Σ amount_paid` and
  `on_credit = sales − collected` from these numbers) and requires a real customer account of the
  company when a tab is left. New idempotent column `orders.tab_amount` — deliberately NOT
  `orders.balance`, which means "change handed back" for a cash sale, so overloading it would make
  invoices and history ambiguous.
- **Closed on the app side** (verified 2026-10-31): the till writes the remainder as a tab — it computes
  `tab`, checks the customer's limit *before* anything is written
  (`calculator_screen.dart:1449-1470` via `CustomerLedgerHelper.exceedsLimit`) and sends `customerId` +
  `tabAmount`. This bullet claimed "still open" long after it shipped: the backend had been ready first,
  and the app side caught up.
- Gates: backend **41 suites / 568 tests**; `flutter analyze lib` 0 errors; Flutter **426 tests**.

## Returnable containers shipped (Phase 15) ✅
- **The gap**: the credit ledger answered "who owes me money"; nothing answered "who owes me
  containers" — the one capability eLeader has for the African beer trade (Castel, deployed in
  Cameroon) that this app lacked. Beer moves in returnable crates and bottles, so a crate in a
  customer's yard is money standing still.
- **Shape**: `container_types` + `container_transactions`; the balance is summed from the
  movements (`out − back − writeoff`) and never stored — the same rule as the credit ledger. The
  pile can never go below zero (back/write-off capped by what is held), STAFF record out/back,
  only a MANAGER writes off or edits the list, and containers are goods (not credit) so any
  customer account may hold them.
- **Totals come from SQL** (`GET /containers/outstanding`): the movements endpoint is capped at
  500 rows, so a long history would compute a wrong balance from the local list.
- **Deposits are informational only** — nothing enters the shift/Z-report maths, so no money test
  moved.
- Gates: backend **40 suites / 554 tests**; `flutter analyze lib` 0 errors; i18n **EN=1438 FR=1438**.
  Flutter suite 418 passing with **1 pre-existing failure** at the time
  (`test/company_logo_bytes_test.dart:74` asserted the `notchPayConfigured` getter). **Since closed**:
  `notchPayConfigured` appears nowhere in `lib/` or `test/` any more and the suite is green (456).
- **Next candidates**: auto-create container lines from a crate sale; the supplier-side mirror
  (containers owed to the distributor) with the supplier/PO feature; part-payment → tab (already
  approved); promotions/loyalty.

## Production database audit + "Banga school" comped ✅
- **RLS fix confirmed live**: Render `GET /health` reports `release: 2026-10-24-rls-lockdown`
  (auto-deployed after the push) and `pg_class.relrowsecurity` now returns **zero** public tables with
  RLS off. The critical `rls_disabled` advisor finding is gone.
- **Integrity clean**: no orphan rows (users/orders/inventory/sessions/subscriptions/drinks/
  payment_transactions), no duplicate emails or usernames, no negative stock, no expired-but-paid
  plans; 14 MB, 13 connections, 1 active session, 0 stale sessions.
- **Bug found — subscription vs company drift** (why "Banga school" showed Free after paying):
  company #42 had **five `subscriptions` rows with `status='active'`** (ids 1,2,3,4,37 — sub 37
  starter 5000 XAF campay, 2026-10-23) while `companies` still said `plan='free'`,
  `subscription_status='expired'`, `plan_expires_at='2026-10-11'`. All subscription rows have
  `starts_at`/`ends_at` = NULL, so sub 37 was activated by a build older than today's deploy. The app
  reads the **company** row (`routes/subscriptions.js:116-119`), so a stale active subscription grants
  nothing. **Open gap, own task:** the auto-expire path (`:131-140`) updates only the company row and
  never marks the subscription expired — hence the stale `active` rows.
- **Payments that never complete**: 34 `subscriptions` rows stuck `pending` (29 for company 42, oldest
  2026-09-14, newest 2026-10-24 07:25). Re-test a live CamerPay subscription on the current build.
- **Comp applied and verified (2026-10-24 12:49 UTC)**: no local `.env` (only `.env.example`), so
  `scripts/set_company_plan.js` cannot run here — the owner ran the SQL in the Supabase SQL editor.
  Live state confirmed read-only: company #42 `plan='pro'`, `subscription_status='active'`,
  `plan_expires_at=NULL`, plus one `audit_log` row (`company.plan`, `free -> pro (status active,
  expires never)`, actor `supabase-sql-editor`). The other five companies are untouched.
  Optional cleanups NOT applied: trailing space in the name, the duplicate `login_requests` index,
  the 3 missing FK indexes. (The legacy anon RPC revocation has since been done — see below.)
- **Legacy RPC surface — VERIFIED CLOSED 2026-10-29**: `get_current_user_id`, `get_user_id`,
  `get_user_id_simple` (+6 `get_*` helpers) are SECURITY DEFINER, and an unauthenticated call with
  the app's publishable key now answers **`401 {"code":"42501","message":"permission denied for
  function get_current_user_id"}`**. They still exist (a non-existent function answers `404
  PGRST202` — that is how the two were told apart) but `anon` has no EXECUTE. Do **not** drop them:
  `update_updated_at_column` is still used by triggers on `companies` + `payment_transactions`.
- **Anon surface probed 2026-10-29 (live, with the app's publishable key):** `companies`, `users`,
  `orders`, `subscriptions`, `payment_transactions`, `inventory_transactions`, `refunds`,
  `audit_log`, `sessions` all answer **404** — the client privileges are revoked, which is stronger
  than RLS alone. Backend routes were probed too: `/api/payment/initiate`,
  `/api/payment/campay-initiate`, `/api/subscriptions/initiate`, `/api/subscriptions/campay-initiate`,
  `/api/company-settings`, `/api/payment/campay-settings`, `/api/admin/users`, `/api/users`,
  `/api/data/drinks` all answer **401** without a session. Only `/api/ping`, `/health` and
  `/api/subscriptions/campay/health` are anonymous, by design.
- **Minor**: duplicate index on `login_requests` (`idx_login_requests_token` ≡
  `idx_login_requests_request_token`, created by hand, not by any repo script); 3 FKs without covering
  indexes (`users.company_id`, `approval_logs.staff_id`, `login_requests.approved_by`);
  `companies.name` for #42 carries a trailing space.
- **Drinks/inventory audit (read-only, 2026-10-24)**: 16 drinks ↔ 16 inventory rows, 1:1, zero orphans
  either way; no zero/negative prices, no selling below cost, no negative stock, no duplicate names or
  barcodes, no inactive drink holding stock; the denormalized copies in `inventory`
  (name/category/unit/purchase_price/company_id) and the min thresholds are 100% in sync.
  **`drinks.current_stock` disagrees with `inventory.quantity` on 11 of 16 rows — that is BY DESIGN**:
  `data.routes.js:54-56` keeps the column non-writable and `:137` returns
  `COALESCE(i.quantity, d.current_stock, 0)`, so never "fix" the legacy values by copying them.
  Real findings: 1 expired drink still in stock (#42 "supermont", expired 2026-09-23, 6 units), 1 drink
  genuinely below minimum (#36 "top", 4 vs min 17), 7 of 16 drinks have no barcode, 14 of 16 have no
  batch dates.
- **Incident (2026-10-24): `drinks.current_stock` was dropped by hand in Supabase** → `GET
  /api/data/drinks` 500s (`42703: column d.current_stock does not exist`) because
  `data.routes.js:137` COALESCEs it. Nothing else depended on it (0 views, 0 functions referenced it).
  Restored by the owner in the SQL editor with `ALTER TABLE public.drinks ADD COLUMN IF NOT EXISTS
  current_stock INTEGER DEFAULT 0` (no repo script ever created the column, so the type was inferred
  from its integer values and its sibling `minimum_level`) and **verified live**: the column is back
  (`integer`, default 0) and the backend query now returns all 16 drinks — total effective stock 169
  units (the stale legacy sum was 126). The legacy values are not recoverable and do not matter,
  because the API prefers `inventory.quantity` (intact) and 0 drinks lack an inventory row.
  **Lesson: that column is load-bearing for the query even though nothing writes or reads it.**
  Either keep it, or drop the reference (`COALESCE(i.quantity, 0)`) and self-heal/remove the column
  deliberately — still open.

## Supabase MCP is callable again (read-only) ✅
- **Symptom:** the Supabase MCP server was already configured in Cline
  (`%APPDATA%\Code\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json`,
  `--read-only`, project `hcfhnooabhxbdfgvtqhp`, `disabled:false`) yet the agent got **no** MCP
  tools at all.
- **Cause:** the args asked for `@supabase/mcp-server-supabase@latest`, so every start did a
  registry round-trip; the first cold start took **>60 s** (npx download) and the server was not
  connected when the task began. Warm start measured: **8.3 s**.
- **Fix:** pinned `@0.14.0` + added `--prefer-offline` (old file backed up to
  `%TEMP%\cline_mcp_settings.backup.json`). Server exposes 7 tools: `search_docs`, `list_tables`,
  `list_extensions`, `list_migrations`, `execute_sql`, `query_logs`, `get_advisors`.
- **Fallback bridge** (for a task that starts without MCP tools):
  `%USERPROFILE%\.cline-tools\supabase_mcp_call.js <toolName> [jsonArgsFile]` — same stdio
  JSON-RPC, reads the token from the Cline settings file and never prints it. Verified live with
  `list_tables`, `execute_sql`, `list_migrations`.
- **Fixed (same day):** `public.audit_log`, `public.legal_acceptances` and `public.refunds` had
  **RLS disabled** (confirmed live via `pg_class.relrowsecurity`) while the backend's boot sequence
  already locked 9 other tables — these three were simply missed, and `sql/legal_acceptances.sql` /
  `sql/refunds_audit.sql` created them with no `ENABLE ROW LEVEL SECURITY`. Now: `server.js` enables
  RLS **and** revokes anon/authenticated on all three at boot (same try/catch style as the
  `subscriptions` + `app_flags` block), both schema scripts do it too, `sql/enable_rls.sql` Tier 1
  lists them (verify query + rollback updated), and `tests/schema_hardening.test.js` gained a
  *money / audit evidence hardening* guard so a refactor cannot re-open the anon key. `RELEASE` bumped
  to `2026-10-24-rls-lockdown` — **the live DB stays exposed until the backend reboots** (or the
  `enable_rls.sql` block is pasted into the SQL editor). Backend **39 suites / 532 tests** green.

## The calculator reads French now ✅ (i18n sweep, part 1)
- **Symptom:** the app is bilingual but the selling screen was not — 27 user-visible strings were
  hardcoded English, including `'Invalid phone number for $paymentMethod'`, the payment outcome,
  the waiting-for-PIN dialog, `LOW STOCK`, the add/remove/clear toasts and the MoMo transfer hint.
- **Now:** all of them come from `i18n.dart` with EN **and** FR values (`calc…` keys). `t()` takes no
  parameters, so sentences with a value are composed around it (`'${t('calcInvalidPhone')} $method'`) —
  word order differs between the two languages, so a template would not have worked without a new
  parameter API. Two messages that showed a raw exception to the operator now show our own sentence,
  with the technical text going to `debugPrint`.
- **Also swept:** `storage_status_widget` (3 buttons — the file had no i18n import at all),
  `storage_settings_screen` (Country, Phone Number, Notch Pay Sync Account ID + hint),
  `manager_approval_screen` (dialog sentence, label, tooltip), `main.dart` (window title),
  `inventory_screen` (pre-filled Restock reason).
- **Verification that matters:** every one of the 97 `t()` keys used in the calculator exists in both
  maps (a typo would print the raw key on screen), and the only English left in that file is the app
  name and the provider brand names. Note for future edits: `t()` cannot be used inside a `const`
  widget — one `const InputDecoration` had to be relaxed.
- **Gates:** analyze 0 errors; Flutter **341 tests**; i18n **EN=1230 FR=1230**. Commit `3db4e35`.
- **Sweep 2 done (`7d8d4e5`):** the lock screen (7 strings: invalid PIN + attempts, session terminated,
  previous device, redirect notice, log in again, use fingerprint/PIN), the invoice panel (5: title,
  invoice/item counts, Filter, Order #) and the drawer's `No Company` (3 — the key already existed, so
  it reuses it; the analyzer caught my duplicate as a duplicate const-map key). Counts are now chosen
  from the map, so French gets facture/factures and article/articles — not an English `s`.
  i18n **EN=1245 FR=1245**.
- **Still to sweep (verified to contain some, not yet fixed):** `auth_screen.dart` (login/register/forgot
  — the first screen anyone sees), `manager_panel.dart` (staff dialogs), `notification_service.dart`
  (notification titles), `auth_provider.dart` (pending-approval messages),
  `storage_settings_screen.dart` (theme names and more). **Unverified:** `drink_management_screen`,
  `admin_panel`, `forecast_screen`, `variance_screen`, `scanner_screen`.
- **Sweep 3 done (`20a247e`):** `auth_screen` — the first screen anyone sees. The reset-code success
  dialog, the slow-server notice, the verification banner, the no-internet dialog, the phone `Format`
  label, *Register as Business Manager*, *Manage your own company and staff*, *Company not found*,
  *Could not verify*. The **seventeen** error dialogs all passed the literal `'Error'` and the success
  dialogs `'Success!'`, so instead of seventeen fragile edits the two helpers translate their own
  heading (`title == 'Error' ? t('error') : title`) — one place to keep bilingual, no call site missed.
  Three keys I added already existed (duplicate const-map keys, caught by the analyzer); the existing
  values were kept.
- **Sweep 4 done (`c293c8f`):** `manager_panel` — block/unblock confirmations and their Cancel buttons,
  *Please fill all fields*, *Staff created!*, *Unblocked*, *Error loading staff*, the bare *Failed*
  fallback, the `Error:` prefix on three catches, and the role dropdown (which displayed raw
  `Staff`/`Manager` while the API value must stay raw — now `role_Staff`/`role_Manager` for display).
  i18n **EN=1260 FR=1260**.
- **Sweep 5 done (`33f997b`):** the manager-approval flow — `auth_provider`'s waiting dialog (*please wait for
  a manager to approve your login on*, the Managers list, *this request expires in 15 minutes*, *checking
  automatically every 10 seconds*; the emoji lines around them are logs and were left) and
  `manager_approval_screen` (empty state, the `Device:` line with its *Unknown* fallback, *Requested to log
  in on a new device*, and a username fallback that printed the literal `Staff` as a person's name — now
  the existing `role_Staff`).
- **Sweep 6 done (`fe767df`):** the inventory screen **end to end** — three section headers, every detail
  row label (Current stock, Minimum level, Status with its Low stock / In stock values, Last restocked,
  Purchase price, Selling price, the N/A fallback, Profit per unit, Profit margin, Total stock value,
  Potential revenue, Potential profit, Category, Unit), the stat chips, two toasts, and the Restocked /
  Price lines — plus the invoice panel's *Items preview*, *Edit & re-invoice* and *Invoice details*.
  **The sort menu needed a real fix**: it used the same English string as label *and* stored value, so
  translating it would have broken the sort switch — new pure `utils/inventory_sort_helper.dart` (with a
  test) maps value → key. i18n **EN=1296 FR=1296**; Flutter **344 tests**.
- **Sweep 7 done (`1882c72`):** `lock_screen` closed out (the biometric prompt, its PIN-pad twin *Use … instead*,
  *Skip PIN setup*, and the *Version* label — the `1.0.0` itself is hardcoded and should come from the package
  version, a separate concern). This is the last screen a user meets **before** anything else, so login →
  lock → till → invoice history are all bilingual now. i18n **EN=1299 FR=1299**.
- **`storage_settings_screen.dart` is NOT a small file** (corrected estimate): it holds **40+** user-visible
  strings — *Currency settings* (×2), *Read only* (×3), *…managed by your company manager* (×3),
  *Currency position*, *Currency symbol*, *Number format*, *Left ($100)* / *Right (100Frs)* (where the raw
  `'left'` comparison value must NOT change), *Company-wide*, *All staff will use these currency settings*,
  *Live preview*, *Company information* (×2), *Business payment settings*, *Reduce spacing and font sizes…*,
  *Valid phone number* and the theme names. **Sweep 8 below finished it.**
- **Sweep 8 done (`9ceea20`):** `storage_settings_screen.dart` finished — **37** new `st_*` keys cover
  every remaining string: the theme picker (*Light/Dark/Active*), *Currency settings* (×2), *Read only*
  (×3), the *…managed by your company manager* notes (×3), *Currency position*, *Left ($100)* /
  *Right (100Frs)* (the raw `'left'` comparison value left untouched), *Company-wide*, *All staff will
  use these…* (×2), *Number format*, *Live preview* + *Unsaved*, *Company information* (×2), phone
  *Format:* with the Cameroon/Nigeria digit warnings, *Business payment settings* (its
  `st_enableBusinessPayments` already existed → reused, not duplicated), the RECEIVE-payments hint (×2),
  *Credit card*, the Orange phone label, the Storage-Statistics rows + *Last backup* / *Never*, the
  backup note and the Clear-All-Data warning. **Deliberately still English:** the brand names (*MTN*,
  *MTN Mobile Money*, *OM*, *Orange Money*) and the `_countries` map's `'name'`s, which are lookup keys
  for the already-translated `country_Cameroon`/`country_Nigeria`; `!= 'Never'` also stays raw because it
  tests the sentinel `StorageService` returns. **Naming note:** the new keys use this screen's existing
  `st_` prefix — *not* `set_*`, which in this codebase means *Set Min*. Gates: analyze 0 errors ·
  `flutter test` **344 passed** · i18n **EN=1336 FR=1336** · all **136** `t()` keys used in the file
  resolve in both maps.

- **Sweep 9 (9a `7c9756a`, 9b `c2f47a5`, 9c `2af1ef2`) cleared the rest of the list.**
  `custom_drawer.dart`: *Admin Panel* → the existing `adminPanel` key, the *No email* fallback, the
  *Version* line. `admin_panel.dart`: the four `'Error: $e'` toasts now show `errorGeneric` and send
  the exception to `debugPrint`; the role dialog shows `role_$r` labels while still sending the raw
  role. `forecast_screen.dart` + `manager_dashboard.dart`: same treatment for their raw-exception
  toasts. `variance_screen.dart` and `scanner_screen.dart` needed **nothing** — already keyed.
  The key audit also caught two **pre-existing missing keys**: `admin_blockFailed` /
  `admin_unblockFailed` were passed as fallbacks but never defined, so they rendered as literal key
  names; both now exist.
- **`notification_service.dart`: user-visible, not a payload.** The drawer list, the OS notification
  and the TTS announcement all show the same sentence, so 28 `notif*` keys cover titles, bodies and
  spoken lines (the TTS *voice locale* is a separate concern). Messages are still composed around
  `t()` because it takes no parameters.
- **`drink_management_screen.dart` units are DATA, not copy.** `unit` is stored on the drink and
  printed, and companies add units of their own. The dropdown did `t('unit_' + unit)`, which rendered
  a custom unit as the bare key `unit_Sachet`; the new pure `utils/unit_label_helper.dart`
  (+ `test/unit_label_helper_test.dart`, 5 tests) translates the eight canonical units and shows a
  custom one verbatim. Also swept: the AppBar title, the *Category* and *Unit* labels, and the
  stock-value line (which had an English `(s)` plural hack).
- **Still English on purpose:** brand names (`MTN`, *Orange Money*, `OM`), AI prompts
  (`forecast_screen`'s Groq prompt, `groq_service`), the country map's lookup `'name'`s, prefs keys,
  HTTP headers, `payment_service` codes.
- **Sweep 10 (`223de03`) cleaned the last of this class.** `receipt_print_screen.dart:251` and
  `admin_support_reports_screen.dart:115` now show `errorGeneric` and send the exception to
  `debugPrint`. The same scan found five more hardcoded strings in `manager_approval_screen.dart`
  (`'Error: $e'` ×2 plus the fallbacks `'Error processing approval'`, `'Member approved'`,
  `'Request rejected'`, `'Error processing request'` — they sit *inside* a call, which is why the
  line-based scans missed them) → 4 new `approval*` keys. Gates: analyze 0 errors · **349 tests** ·
  i18n **EN=1372 FR=1372**.
- **Same class, still untranslated** (service-level messages, decide before changing):
  `api_client.dart`'s `'Request failed with status: N'` and `backend_auth_service.dart`'s
  `'Failed to get join requests'` / `'Failed to process join request'` — either keys, or error codes
  mapped like `PaymentErrorHelper` does. Also still showing a raw exception next to a *translated*
  label (deliberate? the label is bilingual, the detail is diagnostic): `manager_panel.dart` ×5,
  `side_slider.dart`, `profile_screen.dart`, `storage_settings_screen.dart`, `ai_assistant_screen`.
- **One app version, everywhere (`42b7245`, value set to the release in `be084ab`).** The app was
  showing three numbers: the drawer said 1.1.0 (in two different layouts), the lock screen 1.0.0,
  support reports 1.1.0 — while `pubspec.yaml` said `1.0.0+1`. Now there is a single declaration,
  `AppConstants.appVersion` (`lib/utils/constants.dart`, **`1.1.0`** since `be084ab`), read by both
  drawer layouts, the lock screen, `StorageService.createBackup` and `SupportService.appVersion`.
  `pubspec.yaml` is `1.1.0+1`; Android (`flutter.versionName`) and iOS (`$(FLUTTER_BUILD_NAME)`)
  derive from it, so there is no second copy to edit.
  `lib/utils/app_info_helper.dart` (pure: parse the pubspec version, list version literals in a
  source string) backs `test/app_info_test.dart`, which fails when the constant and pubspec disagree
  **or** when any other file hardcodes a version inside a string literal — it immediately caught a
  second `1.1.0` in the drawer that the greps had missed. The guard compares the version *name*, so a
  build-number-only bump (`1.1.0+2`) touches pubspec alone. Gates: analyze 0 errors · **352 tests**.
- **Card at the till: the customer now pays on their own phone (`445ec52`).** Card was already wired end
  to end (`PaymentMethod.card` → `campay-initiate` with `card` → CamerPay rail `stripe` → `checkoutUrl`),
  but the app opened that page **on the till's own browser**, so a tablet had to be handed over and a
  fixed desktop could not take a card at all. Now the backend draws a **QR of the same checkout URL**
  (`drinks-calculator-backend/utils/paymentQr.js`, npm `qrcode`) and returns it inline as `qrPng`; the
  waiting dialog shows it with `Image.memory` (white pad so it scans on the dark theme) plus **Open here**
  and **Send link**, while the existing 10 s server poll settles the sale. No new Flutter dependency, no
  card data anywhere near the app, and the QR is drawn by the request that created the payment so it can
  never point at another sale. That dialog also lost its last hardcoded labels (Amount/To/Phone) and hides
  Phone for card: `payScanQr`, `payScanQrHint`, `payOpenHere`, `paySendLink`, `payShareText`, `payTo`.
  Gates: analyze 0 errors · flutter **352 tests** · backend **400 tests** · i18n **EN=1378 FR=1378**.
- **CamPay has no NFC / SoftPOS** (their own product pages, 2026): the "terminal" is explicitly *sans
  matériel* — amount typed in the dashboard → link/QR → the customer pays on their phone. Cards run
  through Stripe (PCI-DSS L1, 3-D Secure); refunds are 1-click in their dashboard. A real tap at the till
  therefore means a **bank POS terminal recorded in the app**, not our software; revisit only if CamPay
  ships SoftPOS with an SDK.
- **"Server-side amount" is NOT a one-liner — the money is not linked to the sale.** The till creates the
  order *after* payment (`calculator_screen.dart:960`: `_createdOrder?.id ?? timestamp`), so
  `payment_transactions.order_id` is often just a timestamp and the server has no order to read a total
  from. The proper fix is **pending order first** (create the order `pending` with a server-computed total
  → pay with that id → mark paid on settlement / cancel on timeout), which touches stock, the offline
  queue and the Z-report: a deliberate task, not a drive-by edit. **Foundation landed in `2fc420f`:**
  `utils/orderPricing.js` (pure — 24 identical lines collapse to qty 24, an unknown drink invalidates the
  quote instead of being dropped, bad quantities rejected, 2-dp rounding; **12 Jest tests**) and
  `POST /api/orders/quote` (company-scoped, prices from `drinks`).
  **SOLVED DIFFERENTLY in `c62e59f` — no schema change needed.** Instead of pending orders, the price is
  *signed*: `/orders/quote` returns `quoteToken` (HMAC-SHA256 over company + total + unit count + expiry,
  `utils/orderQuote.js`, **15 Jest tests**) and **both** payment routes run `checkQuote` before touching a
  provider — a supplied token is always verified, and the amount must equal the signed total. The till
  quotes the cart first, refuses to charge a total the operator did not see (`calcPriceChanged`), then
  passes the token. Stateless: no rows to clean up, and nothing changes in stock or the Z-report.
  **Rollout (human):** set `ORDER_QUOTE_SECRET` (16+ chars) → ship/verify the build that sends
  `quoteToken` → then `PAYMENT_QUOTE_REQUIRED=true` to make it mandatory (documented in `.env.example`).
  Edge case: a cart holding a drink not yet synced to the server cannot be priced (`valid:false`), so the
  till falls back to the old behaviour until the requirement is switched on.
- **Terms/Privacy consent was UI-only — now it is recorded (`6c5a2fa`).** Audit of the signup flow found:
  the Register button *was* gated on the checkbox (`auth_screen.dart` → `(_isSigningUp || !_agreeToTerms)
  ? null : _handleSignup`) and both documents were linked to the real pages (`public/terms.html`,
  `terms.fr.html`, `privacy.html`, `privacy.fr.html`), **but nothing was ever sent, validated or stored** —
  `register()` posted no consent flag, `/api/auth/register` did not read one, and no column/table held it, so
  a direct API call could register with no consent at all and there was no evidence of what was accepted.
  Now: `_handleSignup` re-checks the box (it is also reachable from the connectivity auto-retry), the app
  posts `termsAccepted`, and the backend writes **two rows per signup** into `legal_acceptances`
  (user, document `terms`/`privacy`, `LEGAL_VERSION`, timestamp, first X-Forwarded-For hop) — table created at
  boot and scripted in `sql/legal_acceptances.sql`. `utils/legalAcceptance.js` holds the rule (8 Jest tests).
  An explicit `false` is always refused; a missing flag (older build) is tolerated until
  `LEGAL_ACCEPTANCE_REQUIRED=true`, which is the rollout switch documented in `.env.example`.
  Gates: analyze 0 errors · flutter **352 tests** · backend **435 tests** · i18n **EN=1380 FR=1380**.
  **Still open:** (1) staff created by a manager (`server.js` inserts at ~1520/1552) never accept the terms —
  no rows for those accounts; (2) bumping `LEGAL_VERSION` records new acceptances but does not *ask* existing
  users again (needs a "terms updated" prompt on next login); (3) the login footer consent line is
  informational only, by design.
- **Login capacity: native bcrypt + a cap on password work (`82d8f50`).** The server used `bcryptjs`
  (pure JS) — one login ≈ 200-400 ms of **main-thread** work, so a shift-start burst froze the whole API
  (payments, `/health`, dashboards) and 500 logins in the same minute ≈ 2 minutes of dead server. Now:
  native `bcrypt` (same `$2b$` hashes, so every existing password still verifies), which runs on libuv's
  threadpool; all **5** hash/compare call sites (login, register, reset, legacy-plaintext upgrade, staff
  creation) go through `utils/authQueue.js` (`createQueue`, 6 Jest tests: limit, FIFO, rejection frees the
  slot, sync throw, clamp, 50-job burst) so at most `AUTH_CONCURRENCY` (8) hashes run at once and the rest
  queue. `UV_THREADPOOL_SIZE=8` + `AUTH_CONCURRENCY=8` documented in `.env.example`. Measured here: 135 ms
  hash / 132 ms compare. **P0+P1 landed in `c63655c`:** the per-request `SELECT 1` keep-alive middleware is
  gone (the pool already keeps TCP connections alive, and `pool.on('error')` now logs a dead idle client
  instead of crashing), and session lookups are cached (`utils/sessionCache.js`, **9 Jest tests**: TTL,
  per-user invalidation, bounded eviction, TTL 0 = off). Revocations delete the entry immediately — logout,
  blocking a user, a login from another device, a manager-approved device change — so an authenticated
  request now costs **zero** database round-trips in the common case. **Then `e21abd0`:** rate limiting
  became a bounded, self-pruning module (`utils/rateLimiter.js`, 7 Jest tests — the old inline Map never
  released a key, a slow leak exactly under attack) and login gained a **per-network** ceiling
  (30 / 15 min per source IP, checked before any hashing) on top of the per-account 10 / 15 min; the four
  hot-path indexes (`orders(company_id,date)`, `payment_transactions(company_id,created_at)`,
  `inventory_transactions(company_id,date)`, `drinks(company_id,is_active)`) are created **at boot**
  (idempotent, failure logged not fatal) and documented in `sql/indexes_hot_paths.sql`.
  Gates: backend **457 tests / 33 suites** · `node --check` clean.
- **Company-till offline rule (option C) + completion percentage (`a06eb6b`).** Chosen policy: cash keeps the
  shop open during an outage, but the unsynced queue has a **hard cap** (20) and electronic money never
  pretends to work offline — and the rule applies to **company tills only** (`user.companyId != null`), so
  personal use is never restricted. `utils/offline_gate.dart` (pure, **10 tests**) returns
  `allowed` / `allowedOfflineCash` / `blockedOfflineElectronic` / `blockedQueueFull`; the till checks it at the
  start of `_processPayment` and shows the matching EN/FR message (`offlineQueueFull`,
  `offlineElectronicBlocked`, `offlineCashOnly`). The Pay button now shows a real percentage while completing
  (`completingOrder` + `_completionProgress`: 35 % order created → 70 % saved → 90 % stock → 100 %), replacing
  the hardcoded "Processing…". Gates: analyze 0 errors · flutter **371 tests** · i18n **EN=1384 FR=1384**.

- **Staff sale correction window (`75de3d0`).** A staff member may now void / re-invoice **their own** sale
  within **10 minutes** — managers and owners keep unlimited rights. Enforced in the pure rule
  `utils/orderVoid.js` (`canVoidOrder({ user, order, now, windowMs })`, **10 Jest tests**); the route now
  loads the order *before* checking permission, because the rule needs `staff_name` + `date`. Mirrored in
  `lib/utils/order_correction_helper.dart` (**10 tests**) so the UI never offers what the API refuses
  (`_canCorrect(order)` in side_slider; `PurchaseHistory` gained `staffName`, persisted in its JSON). Every
  correction still records who/when/why, restores the stock and shows on the shift report. A test caught a
  real flaw in the first version — it let *any* role correct its own sale; a `staff` role is now required
  explicitly. Also here: a **role/company change invalidates that user's cached sessions** (no 30 s
  staleness) and the dead `widgets/invoice_widget.dart` was deleted.
  Gates: analyze 0 errors · flutter **381 tests** · backend **481 tests**.
- **Refund records + durable audit log (`ddfe412`).** No refund API is wired (the money moves in the CamPay
  dashboard), so the backend now **records** refunds: `POST /orders/:id/refund` (manager/owner only) validates
  amount / reason / provider reference and that the refund never exceeds what is still refundable on the order
  (`utils/refundRecord.js`, **7 tests**), stores a `refunds` row and writes an audit entry;
  `GET /refunds` lists them for the manager. `utils/auditLog.js` (**7 tests**, best-effort insert that can
  never fail the action it documents) writes one `audit_log` row per sensitive action — wired into refunds,
  `user.block` and `user.role` — and, in `e9968f1`, `user.unblock` and `user.delete`. **The refund feature is now
  end to end (`ff46367`):** a manager-only **Refund** button in the order sheet
  (`side_slider._recordRefund`) collects amount (prefilled with the order total), reason and provider reference,
  then `SupabaseService.recordRefund` posts to the endpoint; 10 EN/FR `refund*` keys. Both tables are created at
  boot and scripted in `sql/refunds_audit.sql` (with ready-made audit queries in the comments).
  **Legal gate landed (`2119506`):** `GET /api/auth/legal/status` + idempotent `POST /api/auth/legal/accept`
  (audited as `legal.accept`) and a blocking accept-to-continue dialog right after login
  (`auth_screen._ensureLegalAcceptance`, 5 EN/FR keys) — one mechanism covers manager-created staff AND a
  `LEGAL_VERSION` bump. Declining keeps the user signed out; if the status cannot be read the gate does NOT
  block (a gate we cannot verify must never lock a till). Gates: backend **502 tests** · i18n **EN=1399 FR=1399**.
  **Voice is off by default and plan-gated (`68c629a`).** The global voice switch defaulted to **ON**
  (`voiceEnabled = true`, prefs `?? true`), so every install spoke — including spoken notifications on the
  free plan. Now: `voiceEnabled` defaults **false** and a missing pref key means "never chosen = off"; a new
  `planAllowsVoice` entitlement (pushed by `PlanProvider._syncVoiceEntitlement` on every plan fetch, covering
  boot + restored session + fresh login) must ALSO be true. One question for every speak site:
  `VoiceService.voiceAllowed` (= plan AND user switch), used by `VoiceService.speak` and
  `notification_service._speak`. Rule lives in the pure, tested `lib/utils/voice_access.dart` (**8 tests**).
  Entitlement = the **pro** plan (same as the AI assistant, matching the server's `requirePlan(['pro'])` on
  `/api/ai/*`); an unresolved or failed plan is a "no". A downgrade silences immediately without erasing the
  user's saved preference, so re-subscribing restores it.
  **Enumeration closed (`cf4774b`):** register now answers exactly like a fresh signup (201, same shape, a
  throw-away token that authenticates nothing) and emails the real owner (`sendExistingAccountEmail`) instead of
  returning 400 "Email already registered". The **username-taken** branch still answers distinctly — it needs
  its own template, noted as a follow-up rather than left silently.
  **2FA (option a) — SHIPPED** in `66b2c38` (server), `a380e06` (login retry), `afaec6f` (profile switch).
  Scope: email OTP for managers/admins/owners only, **opt-in per user, off by default** so shipping it could
  never lock anyone out. Built exactly as designed below:
  `POST /api/auth/login { email, password, otpCode? }`:
  1. `users.two_factor_enabled boolean DEFAULT false` (boot DDL, same ALTER pattern as other columns);
  2. `utils/twoFactor.js` (pure + tested): `requiresSecondFactor({ enabled, role, emailConfigured })`,
     `generateOtpCode()`, a bounded self-pruning challenge store (TTL ~10 min, max entries, like
     `utils/rateLimiter.js`), `checkChallenge({ store, userId, code, now })` → `{ ok, code: 'missing' |
     'expired' | 'invalid' | 'ok', attemptsLeft }` (timing-safe compare via `utils/safeCompare.js`);
  3. in the login route, right after the password check: if required and the code is missing/expired → create a
     challenge, email it, reply `401 { status: 'otp_required', message }`; if invalid → `401` with attempts left;
     if **valid → fall through to the existing session creation untouched**. When 2FA is off the route behaves
     exactly as today (zero diff in behaviour);
  4. `POST /api/auth/2fa` (session) to turn it on/off + `sendLoginOtpEmail` template;
  5. app: `BackendAuthService.login` recognises `otp_required`, `AuthProvider.login` surfaces it,
     `auth_screen._handleLogin` shows a 6-digit dialog then retries with `otpCode`; toggle in settings for
     managers/admins only + EN/FR keys.
  Cost note: the retry hashes the password twice (≈2× bcrypt) — acceptable for a 2FA user, once.
  **Shipped extras:** `GET /api/auth/2fa` returns `available` (env flag + mailer + role) and is what the
  profile switch reads, so the switch hides itself until the server can actually deliver a code; the state is
  never guessed locally. `TWO_FACTOR_ENABLED` (off in `.env.example`) is the kill switch — while it is off no
  login is ever challenged and opt-in is refused. An undeliverable code lets the login proceed and logs a
  warning, so a dead mailer cannot lock an owner out. Gate: backend **529 tests / 39 suites** (+27).
  **Username branch closed too (`1a6a205`, option (i)):** a taken username now answers the identical neutral
  201 as a fresh signup + `sendUsernameTakenEmail` tells the truth to the typed address. Trade-off accepted: a
  customer with a taken username is told "check your email" instead of getting instant feedback.
  ⚠️ **Live behaviour changes to sanity-test:** register now emails on a taken email/username, the legal gate
  runs at every login, and voice stays off unless the user had explicitly enabled it before.
  **Still open:** (3) 2FA (needs a product
  decision — email OTP for managers/admins only is the smallest safe scope); (5) registration enumeration
  (needs an asynchronous "if this address is free you'll get an email" flow); (6) unused fields
  (`_isLoading`, `_pendingPassword`, `_allUsers`, `_themeMode`, `mtnWasEnabled`…) need their writes removed —
  cosmetic. Gates: analyze 0 errors · flutter **381 tests** · backend **495 tests / 37 suites** ·
  i18n **EN=1394 FR=1394**.

- **Still to do, in priority order:** ~~(1) the app-side refund action~~ ✅ `ff46367`; ~~(2) **legal gate** for
  manager-created staff and for a legal-version bump~~ ✅ `2119506`; (3) **2FA** (smallest safe scope: email OTP
  for managers/administrators only — needs a product decision); ~~(4) audit entries for unblock/delete~~ ✅
  `e9968f1`; ~~(5) **registration enumeration**~~ ✅ `cf4774b` (username-taken branch still answers distinctly —
  needs its own email template); (6) the remaining unused fields (`_isLoading`, `_pendingPassword`, `_allUsers`,
  `_themeMode`, `mtnWasEnabled`…) also need their writes removed — cosmetic, still open.

- **Bug sweep (`30354c9`): two real bugs fixed, the money paths verified.** (1) **Crash on a bad colour**
  — eight places did `Color(int.parse(hex.replaceFirst('#','0xFF')))`, so one empty/corrupt stored colour
  (failed save, older build, hand-edited pref) threw a `FormatException` **inside `build()`** and killed the
  screen. Now `utils/color_helper.dart` (`parseHexColor`, accepts `#RRGGBB`/`RRGGBB`/`#RGB`/`#AARRGGBB`/
  `0x…`, never throws, falls back to the brand colour; **9 tests**) is used by main.dart, admin_panel,
  manager_panel, manager_approval_screen and storage_settings (4 sites). (2) **Login self-lockout** — the
  brute-force limiter counted *successful* logins, so a staff member signing in on several devices could
  burn the 10-per-15-min budget and lock themselves out; a correct password now clears the account's
  counter (the per-network counter is untouched, so flooding is still capped). **Verified as NOT bugs:**
  the Pay button is guarded against double-submit (`_isProcessingPayment` disables it and is set before the
  async gap), cash is refused when `_amountPaid < total`, a phone is required for MoMo/Orange but not card,
  every `rows[0].` in `data.routes.js` is length-guarded, and the `dead_null_aware_expression` warnings are
  cosmetic (the fields really are non-null there). Remaining analyzer output is dead code only: unused
  fields/imports (`_isLoading`, `_allUsers`, `_themeMode`, `mtnWasEnabled`, …) and unused catch variables.
  Gates: flutter analyze 0 errors · flutter **361 tests** · backend **466 tests**.
- **Security pass (`35b2dec`): three fixes + the honest end-to-end answer.** (1) **The platform-admin override
  fell back to the public string `'admin123'`** when `ADMIN_PASSWORD` was unset (server.js:820) — anyone could
  send `X-Admin-Password: admin123` and block/delete any account on the platform. It now **fails closed**: no
  variable (or < 12 chars) = override disabled, logged at boot; comparisons use `utils/safeCompare.js`
  (`timingSafeEqual`, 5 tests) instead of `===`. **The admin panel therefore needs `ADMIN_PASSWORD` set on
  Render before its actions work again.** (2) **Session tokens were partially logged**
  (`token.substring(0,20)` at logout and validate) — now redacted. (3) **DB TLS verification** was hardcoded
  off (`rejectUnauthorized: false`) — now `PGSSL_STRICT=true` opts in (default unchanged so a wrong CA chain
  cannot take the backend down; verify on staging first). **Confirmed clean:** no hardcoded provider secrets
  (the `sk_live` hits were key-prefix strings), SQL goes through column whitelists, every `rows[0].` guarded,
  card data never reaches the app, and payment signing/legal consent are in place but **switched off until the
  env vars are set** (`ORDER_QUOTE_SECRET`, `PAYMENT_QUOTE_REQUIRED`, `LEGAL_ACCEPTANCE_REQUIRED`).
  Gates: backend **471 tests / 35 suites**.
- **Load test shipped (`dfbe124`) — the capacity plan is closed.** `scripts/load_test.js` logs in once and
  hammers the endpoints a screen really calls (`/api/drinks`, `/api/orders`, `/api/inventory`,
  `/api/settings`), printing p50/p90/p95/p99 + max per path, overall req/s, and an error breakdown; exits 1
  if anything failed so it can gate CI. Credentials are CLI/env only (`LOAD_PASSWORD`), never stored, and
  never printed (`*** (set)`), and `--dry-run` validates the arguments without sending anything (verified:
  exit 0 with arguments, exit 2 without). The percentile maths lives in `utils/loadStats.js` (**7 Jest
  tests**, incl. "one slow request shows in p95 but barely in the mean" and null-is-not-zero). Run it
  against staging: `node drinks-calculator-backend/scripts/load_test.js --base <url> --user <u> --password <p> --requests 400 --concurrency 20`.
  Final gates for the whole session: flutter analyze 0 errors · flutter **352 tests** · backend
  **466 tests / 34 suites** · i18n **EN=1380 FR=1380**.
- **`card_rail` column not needed yet:** with CamPay, card is always the hosted page, so
  `payment_method = 'card'` is already unambiguous. Add it only when a second card rail exists.

- **Gates for sweep 9:** analyze 0 errors · `flutter test` **349 passed** · i18n **EN=1368 FR=1368** ·
  every key used in each swept file resolves in both maps.

- **SUPERSEDED by sweep 9 above** — everything still outstanding was done, including
  `custom_drawer.dart` (only *No Company* was fixed — check the rest),
  `notification_service.dart` (check whether those titles are user-visible), `admin_panel.dart`,
  `forecast_screen.dart`, `variance_screen.dart`, `scanner_screen.dart`, `manager_dashboard.dart`.
  `drink_management_screen.dart` unit options
  (*Bottle*/*Can*/*Glass*) were **data**, not copy: the label is translated while the stored value
  stays canonical (sweep 9 above). **Not UI** (leave): `ai_assistant_screen`
  voice keywords, `groq_service` prompts, prefs keys, HTTP headers, `payment_service` code strings.

## Payment refusals are now said in our words ✅
- **The symptom:** a manager tapping "pay" got CamerPay's own French sentence printed straight onto the
  screen — `"Votre période d'essai gratuite s'est terminée le 12/10/2026. Activez un plan pour reprendre.
  https://camerpay.biz/client/subscription"`. A third party, one language, and a link the user cannot act
  on (that URL is CamerPay's merchant portal — the *platform's* CamerPay account is on an expired trial,
  so the refusal was never ours to explain to a customer).
- **Where it leaked:** `campayErrorResponse` (subscriptions) and the collection catch block
  (payment.routes) returned the provider's `message` verbatim for a 402; the app threw it
  (`Exception(data['message'])`) and `subscription_screen` printed it after stripping the prefix.
- **Now:** new pure `utils/campayRefusal.js` classifies a refusal into a code
  (`campay_account_inactive` / `campay_quota` / `campay_token` / `campay_request_rejected` /
  `campay_not_configured` / `campay_error`) and decides whether the provider's own words are worth
  showing at all. Both rails send `{code, message: <our sentence>, providerMessage: <raw, for the log>,
  providerCode, accountLevel}`; an account-level refusal is a **503**, not a 402 ("we must fix it", never
  "you must pay more").
- **App:** `utils/payment_error_helper.dart` maps the code to an i18n key (`payErr…`), and both paths
  (subscription screen, calculator collection) show that sentence — translated — with the provider's
  detail appended **only** where it is actionable (a KYC/volume limit names the document that raises it,
  a refused request names the field). The raw text goes to `debugPrint` for support. The stale
  `Exception(message)` throw and the `replaceFirst('Exception: ')` display are gone.
- **Gates:** backend **26 suites / 395 tests**; Flutter **341**; `flutter analyze lib` 0 errors;
  i18n **EN=1201 FR=1201**. `RELEASE` → `2026-10-14-payment-error-codes`.
- **Still open:** the blocker itself (activate the platform's CamerPay plan) is operational, not code;
  the B2C legacy Notch Pay rail still passes provider text through (retired rail, untouched on purpose).

## Legal pages carry the real logo, and a password-reset cap that survives restarts ✅
- **Logo:** the four legal pages (`drinks-calculator-backend/public/{privacy,terms}{,.fr}.html`) used a
  hand-drawn placeholder SVG; they now show the app's own artwork, `assets/icons/icon.png`, served as
  `public/logo.png` (byte-identical). It is dark art with transparent corners, so it sits on a white
  tile (`.logo`) to stay legible in the dark theme the pages already support. Changing the logo means
  replacing both files — noted in `.clinerules/01-project.md`.
- **Password reset, before:** 10 requests / 15 min per email, counted **in memory** — so a Render
  restart handed out a fresh allowance, and a wrong 6-digit code could be guessed without limit.
- **Password reset, now:** `utils/passwordReset.js` (pure rules) + `utils/passwordResetStore.js` (the
  SQL, tested with a stub pool) enforce **3 reset emails per address per rolling 24 h** (default,
  `PASSWORD_RESET_MAX_PER_DAY`) and **5 wrong codes per 15 min** (`PASSWORD_RESET_MAX_CODE_ATTEMPTS`),
  counted from the new `password_reset_requests` table (created at boot + `sql/rls_password_reset_requests.sql`,
  RLS on, revoked from anon/authenticated). The request is recorded **before** the account lookup and
  for unknown addresses too, so the 429 cannot be used to find out which emails are registered; a
  correct code clears the wrong tries. The in-memory burst limiter stays as a backstop.
- **Answer to "how many times?":** 3 per day per address (configurable), 5 wrong codes per 15 minutes;
  the 429 carries the retry time and the app already surfaces `message`.
- **Gates:** backend **25 suites / 387 tests** (+15); `node --check` clean; Flutter untouched.
- **Still open (never done):** a status/message key in the app badge for "2 reset emails left today" —
  the endpoint already returns `remainingToday`. `RELEASE` was bumped to
  `2026-10-11-returns-and-reset-limit` so the deploy can be confirmed from `GET /health`.

## Returns — the third correction lane ✅
- **What it is:** "1 of 2 comes back" in one action, instead of void + re-invoice. The sale stays as
  billed and still counts; the unit goes back on the shelf, the money goes back to the customer, and
  the Z-report shows it. Manager-only (it moves stock and opens the drawer, like a void).
- **Backend:** `POST /api/data/orders/:id/returns` + `GET /api/data/orders/:id/returns`, pure
  `utils/orderReturn.js` (28 Jest tests). The ceiling — sold minus what earlier returns took back —
  is read from the movements ledger, never from the client. Stock moves through the same guarded
  `applyStockDelta` a sale uses; the ledger row (`reason 'return'`, `order_id`, `performed_by`,
  `selling_price_at_sale`) is written by the route with `CURRENT_TIMESTAMP` (so it lands in the shift
  window like a void) and is deliberately **not** best-effort, because it is also the ceiling.
  `applyStockDelta` grew a `logMovement: false` flag so the movement is recorded once.
- **Z-report:** new **Returns** line (count · units · value) and **Net sales** (`sales − returns`);
  the refund is subtracted from `expectedCash`, so a cash-up reconciles instead of showing a
  shortage. Flutter shows it in the live card, the Z-report dialog and the WhatsApp report.
- **Flutter:** return button on the invoice card (manager-only, only while the sale counts), a
  quantity-stepper dialog drawn from the SERVER's numbers (`GET` → `utils/order_return_helper.dart`
  → `widgets/return_items_dialog.dart`), mandatory reason, then a stock refresh from the server
  rather than local arithmetic.
- **Product decision taken (as recommended):** returns are their own line with sales left as
  invoiced — net = sales − returns — mirroring how voids are handled.
- **Gates:** backend **24 suites / 371 tests**; Flutter **326 tests**; `flutter analyze lib` 0 errors;
  i18n **EN=1193 FR=1193**.
- **Whole sales / bulk (2026-10-11):** this app is not only bars — a company can sell a whole crate
  sale (24 units on one invoice) and give the lot back. Verified symmetric: the cart adds the same
  drink instance N times, the sale deducts one unit per entry (`_getDrinkSummary`), and the return
  ceiling counts the same way, so a 24-unit sale reads as ONE line "sold 24 · left 24" and a return
  of 20 puts exactly 20 back. The gap was the UI, so the dialog grew a **typeable quantity box**,
  **"All left"** per line and **"Return everything left"** — twenty-four `+` taps is not an answer.
  Both shortcuts sit on `OrderReturnHelper.allRemaining()` (tested).
- **Wording swept (2026-10-11):** bar-only copy removed from everything this feature touched —
  `returnReasonHint` ("damaged / wrong order"), the user + admin manuals ("bar manager", "bartender",
  "protects the bar" → business/location), the privacy/terms tagline on all four legal pages, and
  `projectbrief.md` (now: bars, restaurants and shops). `ROADMAP.md` history left untouched.
- **Next:** first live CamerPay payment; Supabase password rotation; delete the retired Notch Pay code
  once companies are migrated. Known gaps here: no widget test for the dialog itself (its rules are
  unit tested) and a refund is always assumed to be cash out of the drawer.

## Follow-up — re-invoice repaired and manager-gated ✅
- **The bug:** "Edit & Re-invoice" could never finish. `_importInvoice` rebuilt every cart line with a
  made-up id (`import_<ts>_<n>_<name>`, `side_slider.dart`) and nothing mapped it back, so the stock
  commit looked for an inventory row that does not exist → `removeStock` returned false → the sale was
  refused with the insufficient-stock toast while the shelf was full. A partial return (2 sold, 1
  returned) was therefore impossible: no unit came back and both stayed counted as sales.
- **Fix:** new pure `lib/utils/invoice_import_helper.dart` (+10 tests) resolves each line to the REAL
  catalogue drink by name (case/space tolerant), keeps the catalogue identity + stock and the price the
  customer actually paid, expands one cart entry per unit, and **refuses the whole import** when a
  drink has left the catalogue instead of inventing or silently dropping a line.
- **Control:** re-invoice is now gated like a void — a non-manager gets `t('reInvoiceNeedsManager')`
  rather than a half-finished correction (the backend already refused the void, which would have left
  the sale counted twice). `_decreaseDrinkQuantity` lets the manager drop the one unit before paying.
- **Manager flow is now right:** 10 in stock → sell 2 → 8 → re-invoice 1 unit → 7 → original voided
  (stock back) → 9 ✅. Five new EN/FR keys.
- **Still open (its own feature):** true line-level return — return 1 of 2 in one action, recorded and
  reported on the Z-report — instead of void + re-invoice.
- **Validated 2026-10-10:** `flutter analyze lib` 0 errors (506 issues, 49 warnings);
  `flutter test` **316 passed**; backend 23 suites / 343 tests; i18n parity **EN=1176 FR=1176**.


## Latest session — order activate/deactivate audited, then fixed ✅
- **Two lanes were conflated.** Void/Restore (`POST /api/data/orders/:id/void|restore`, manager-only,
  sets `is_active=false` **and** `voided_at`, moves stock) was sound. The calculator's automatic
  rollbacks used a *different* lane: `PATCH /api/data/orders/:id {is_active:false}`, which set
  **only** `is_active`. The Z-report filtered `voided_at IS NULL` alone, so a rolled-back sale kept
  inflating the shift takings/expected cash while the app's analytics (filters `is_active`) excluded
  it. Proven with a throwaway harness: 100 sold + a 50 rolled-back order → `sales 150`,
  `expectedCash 150`, `voidCount 0`.
- **Backend fix**: new `POST /api/data/orders/:id/cancel` records the same trace
  (`is_active=false`, `voided_at`, `voided_by`, `voided_by_name`, `void_reason`) but **never moves
  stock** — the caller has already put back what it took. The Z-report sales query now also requires
  `is_active = true`, and the corrections query catches untraced cancellations
  (`orderVoid.summariseVoids` counts them, `isInactive` added), so a correction stays visible instead
  of the sale silently vanishing.
- **App**: `OrderProvider.toggleOrderStatus` + `SupabaseService.updateOrderStatus` **deleted** — they
  were the only way to create an untracked `is_active=false`. New `OrderProvider.cancelOrder` and
  `voidOrCancelOrder` replace them. The calculator's re-invoice path tries a void first (stock back,
  so the replacement sale does not deduct twice) and falls back to cancel when a staff member may not
  void; both stock-rollback sites cancel with `t('reasonStockRollback')`.
- **Partial stock rollback**: `_deductInventoryFromOrder` now remembers the lines it deducted and puts
  them back (`InventoryProvider.addStock(reason: 'sale_rollback')`) before refusing the sale. It used
  to leave the shelf short by every line that had already succeeded.
- **UI**: the invoice card's button, dialog and toast now all follow one pure decision
  (`lib/utils/order_action_helper.dart`, 7 tests) — a row cancelled without a trace offers "Void" (to
  record the missing trace) instead of "Restore" that secretly voided and re-added stock.
  `'customer'` removed from `_canManageOrders`; the deactivation strings moved into EN/FR.
- **Z-report visibility**: `ShiftSummary` used to drop `voidCount`/`voidValue`, so a cancelled sale was
  excluded from the takings with nothing on screen to explain it — the model, the Z-report dialog and
  the WhatsApp report now carry a `shiftCorrections` line when there is one.
- **Validated 2026-10-10**: `flutter analyze lib` 0 errors (506 issues, warnings 50→49);
  `flutter test` **306 passed**; backend **23 suites / 343 tests**; i18n parity **EN=1171 FR=1171**;
  `node --check` clean on both changed backend files.
- **Known gaps**: no Flutter test for the multi-line partial rollback itself (only the decision rule
  is unit-tested — the widget loop is not), and `getActiveOrders` / `getDeactivatedOrders` + the
  stats map in `order_provider.dart` are now unused.
- **Deliberate widening**: `/orders/:id/cancel` is open to any session of the company (a cashier must
  be able to undo their own refused sale). It never moves stock, demands a reason, records the actor,
  and shows up as a correction on the Z-report; stock-moving void/restore stays manager-only.

## Latest session — support reports complete, Resend, yearly plans ✅
- **Support / bug reporting: DONE.** `utils/supportReport.js` (20 tests) → `POST /api/support/reports`
  (`cb17c0d`) → `support_reports` table + email, then the app screen
  (`lib/screens/support_report_screen.dart` + `lib/services/support_service.dart`, drawer entry
  "Report a problem", 16 EN/FR keys) (`8ab0b55`). Context (platform/appVersion/screen/role/locale)
  is attached by the app, never typed by the user.
- **Email is now Resend, not SendGrid** (`7d6e17d`): `utils/email.service.js` calls the REST API with
  the built-in `fetch` — no SDK, and `@sendgrid/mail` + 7 transitive packages removed.
  Env: `RESEND_API_KEY`, `EMAIL_FROM` (**must be on a domain verified in Resend, or the send 403s**).
  `buildEmailPayload` is pure + tested (6 tests). **Human step: set both vars on Render.**
- **Yearly plans** (`df5163a`): Starter 48 000 / Pro 144 000 XAF (20 % off), keys
  `starter_yearly` / `pro_yearly`, env `STARTER_YEARLY_XAF` / `PRO_YEARLY_XAF`. New
  `utils/planCatalog.js` (8 tests) separates **purchase key** → **tier** → **months bought**, because
  `companies.plan` is ranked by `planAuth` and an unknown name ranks 0 — storing a key there would
  have silently downgraded a bar that had just paid for a year. Enforced on write, on read
  (`/subscriptions/status`) and at the gate (`planRank`). Also fixed a latent `ReferenceError`: four
  legacy verify paths still used the deleted `SUBSCRIPTION_MONTHS`, now `planMonths(sub.plan)`.
  Backend **22 suites / 330 tests**. The app is unaffected until the UI below lands (extra price
  keys are additive).
- **SendGrid restored** (`53dea09`): the user has no domain to verify, and SendGrid only needs a
  verified Sender **address**. Resend is reverted; `buildEmailPayload` / `isEmailConfigured` were
  kept (6 tests) and `EMAIL_FROM_NAME` added.
- **Card subscription fixed** (`2936e7d`): the card button called the LEGACY Flutterwave endpoint
  *and* polled only our own DB, so a payment CamerPay had accepted sat as "pending verification"
  (the webhook HMAC recipe is still unproven live). `_upgrade` now uses the CamerPay card rail plus
  the authoritative `GET /subscriptions/campay-status` poll the MoMo rail already used, and
  `_momoPay` no longer swallows CamerPay's error message (402 KYC limit now reaches the user).
  `PlanProvider.initiate` / `SubscriptionService.initiate` (Flutterwave) are now dead code.
- **Both follow-ons DONE.** Yearly UI (`3a6dcaa`): a Monthly/Yearly `SegmentedButton` on the
  subscription screen; `_pricingCard` derives the tier from a yearly key (`pro_yearly` → `pro`) so
  the current-plan state still matches, and the price suffix follows the period. Admin support
  inbox (`9b7278d`): `GET /api/admin/support-reports` (filters + per-status counts, 500-row cap) and
  `PATCH /api/admin/support-reports/:reference` (`COALESCE`, so a note-only update keeps the status),
  both behind `verifyAdmin`; screen reached from an inbox button in the admin panel AppBar. i18n
  parity **EN=1160 FR=1160**.
- **Owner flag fixed** (`3e83b7e`): logging in as an owner showed `isOwner:false` in the app while
  the backend sent `true` — so every owner-only action was hidden from the real owner. Two
  independent drops: `BackendAuthService.User` had **no `isOwner` field at all** (the flag was
  discarded while parsing the login/me response), and `AuthProvider` hand-builds `User` in three
  places where it defaults to `false`. Both layers fixed; `test/owner_flag_test.dart` (6 tests)
  pins parsing, snake_case and the storage round trip. Flutter total: **299 tests**. ⚠️ The login
  path still assembles `User` by hand (it owns the id/companyId fallbacks) — extracting that into a
  tested helper is the real follow-up.
- **Session dialog, PIN countdown, RLS** (`8447821`, `0f0e80b`): (1) the session-terminated dialog
  is now wrapped in `PopScope(canPop: false)` — the Android back button used to close it and leave
  the user on the calculator with a session the server had already invalidated. (2) The PIN lockout
  (5 wrong tries → 30 s) ticks a **live countdown** (`lockTryAgainIn`, "Try again in 12s") instead of
  a silent `Timer`; shown in the locked panel, the subtitle and the toast. (3) `support_reports`
  gained RLS: `sql/rls_support_reports.sql` (from the `rls_shifts.sql` template) **plus** enforcement
  at boot in a try/catch block (the anon/authenticated roles only exist on Supabase).
  Flutter 299 tests; parity EN=1161 FR=1161.
- ⚠️ **Process rule learned:** never run two `git` commands concurrently in one tool call — they race
  on `.git/index.lock` and stage each other's files (it happened once here: a commit took the wrong
  message; fixed by amending the message only, then `push --force-with-lease`).
- **Pending-login & approval fixes** (`fb58433`), four separate reports:
  (1) the login-approvals list showed the role **"Staff"** instead of the name — the backend field is
  **`staff_username`** (`u.username AS staff_username`), and the screen read `request['username']`;
  (2) the waiting-for-approval dialog was partly invisible in dark theme — a fixed
  `Colors.blue.shade50` panel under theme-coloured text, plus `Colors.grey[600]`; now
  `primaryContainer`/`onPrimaryContainer`/`hintColor`;
  (3) after approval the staff ran with **no companyId** until a manual logout/login —
  `_completeApprovedLogin` fetched the profile with `getUserByUsername()` **before** saving the new
  session token, and that call returns null when storage has no token (always true on a new device),
  so it persisted the `companyId: null` fallback. Now `/auth/me` with the token passed explicitly
  (`getCurrentUser({String? sessionToken})`) **plus** a post-save retry that recovers the company;
  (4) the lock screen stated the wait twice — only the timed panel (timer icon) says "try again",
  the subtitle/toast say "Too many attempts" (`lockTooManyAttempts`, EN/FR).
  Flutter 299 tests; parity **EN=1162 FR=1162**.

## Current focus — CamerPay migration (Notch Pay → CamerPay) 🔄
- **Decision (user):** drop Notch Pay entirely; CamerPay handles everything — platform
  subscriptions **and** per-company (B2C) collections, card (Stripe) and PayPal included.
  Each bar connects its **own** CamerPay account (option B): its own Bearer token, its own KYC.
- **Phase 0 done — CamerPay facts** (camerpay.biz/docs): `POST /api/payment/initiate`
  (per-merchant Bearer token; `merchant_invoice_id`, `merchant_callback_url`,
  `merchant_return_url` required; `payment_method` = orange_money | mtn_momo | stripe |
  paypal), `GET /payment/{uuid}/status`, `POST /payment/{uuid}/refund`,
  `POST /payouts/batch`. The webhook is **form-encoded (not JSON)** with
  `X-CamerPay-Signature` = HMAC-SHA256 hex over the **raw body**; only network errors are
  retried, so any 4xx/5xx is final and recovery is the dashboard "Rejouer" button. KYC:
  1 = 200 000/mo (CNI **or** RCCM), 2 = 1 000 000/mo (+NIU), 3 = **unlimited**
  (RCCM+NIU+domicile); over-limit = HTTP 402 `kyc_tier_volume_exceeded` carrying
  `next_action`/`upgrade_url` (5 % tolerance, `completed` non-sandbox only).
  **The token cannot reveal test vs live — the account decides**, so the only trustworthy
  signal is `is_sandbox` from the status endpoint. Commission is deducted from the merchant
  and there is **no fee field**, so "fees included" is our own gross-up.
- **Phase 1 ✅ (`2b00cd0`):** `utils/campay.js` (initiate/status/refund/HMAC/typed errors),
  `utils/credentialVault.js` (AES-256-GCM, fails closed), `utils/paymentFees.js` (fee +
  limits + gross-up) with 71 new Jest tests.
- **Phase 2 ✅ (`6e6a731`):** additive subscription rail — `POST /subscriptions/campay-initiate`,
  `GET /subscriptions/campay-status`, `POST /subscriptions/campay-webhook`,
  `GET /subscriptions/campay-return`, `GET /subscriptions/campay/health`; pure gate
  `utils/subscriptionPayment.js` (a **completed sandbox payment never activates** — refused
  before any amount check); provider-neutral `PAYMENTS_REQUIRE_LIVE` /
  `PAYMENTS_ALLOW_UNDERPAYMENT` (old `NOTCHPAY_*` names still honoured); and
  `express.urlencoded` now captures the raw body, without which every form-encoded webhook
  signature would have failed. Backend Jest: **17 suites / 264 tests**.
- **Next:** phase 3 (B2C per bar: vault columns, per-company webhook token, fee excluded
  from bar revenue and shown as its own Z-report line), phase 4 (Flutter "Connect CamerPay"
  screen), phase 5 (delete Notch Pay, then retire the legacy MTN/Orange rails once every bar
  has KYC). **Blocked on the human:** a CamerPay **sandbox token** (to pin the signature
  recipe) and the **fee rates** per method.

- **Phases 3, 4, 5.1, 5.2 ✅** (`fd4f1fd`, `70c3f4a`, `47a5da5`, `bd1c8fc`, `37fc37d`,
  `0372f69`): per-company credentials (AES-256-GCM, write-only, fails closed on a key
  mismatch), `GET/PATCH /payment/campay-settings` (manager-gated, masked), the collection pair
  `POST /payment/campay-initiate` + `POST /payment/campay-webhook/:companyToken` (opaque
  per-bar token in the path, raw-body HMAC with THAT bar's secret, then authoritative
  re-verification; a sandbox payment never marks an order paid; fee is the bar's cost, never
  added to what the customer pays), the "Connect your CamerPay account" card in Storage
  Settings, `payment_transactions.provider` so the till's status polling ignores CamerPay rows,
  and the till now prefers CamerPay with a legacy fallback.
- **Deliberately deferred — 5.3**: delete the Notch Pay paths and drop `notchpay_*` /
  `card_enabled`. **Do not do this until bars have connected CamerPay**: `campay_enabled`
  defaults false and no bar holds a token yet, so removing the legacy rail now would stop every
  bar from collecting. Retiring the legacy MTN/Orange rails follows the same rule.
- **Still on the human:** `PAYMENT_CREDENTIALS_KEY` on Render (without it the connect screen
  correctly refuses with `vault_key_missing`; it must stay stable or stored credentials become
  unreadable), each bar completing its own CamerPay KYC and copying its **webhook secret**, the
  CamerPay fee rates per method (`CAMERPAY_FEE_*` — the API does not publish them), and rotating
  the Supabase database password (see the security note below).

### Security findings (2026-10-07) — dependency audit
- **Production tree is now clean**: `npm audit --omit=dev` reported 15 advisories
  (1 critical, 10 high) before, **0 after**. Two causes: (a) **seven declared
  dependencies the code never used** — `socket.io` (which alone pulled in `ws`,
  `engine.io`, `socket.io-parser`, `socket.io-adapter`), `multer`, `nodemailer`
  (email goes through `@sendgrid/mail`), `morgan`, `pdfkit`, `cloudinary`, and the
  bogus `crypto` package (Node builtin; the npm one is an empty stub) — each proven
  unreferenced across the whole backend before removal; (b) stale transitive
  versions, cleared by `npm audit fix` (lockfile only, `package.json` ranges
  untouched). Commit `968ed42`, 278/278 tests green.
- The critical was never reachable: Express only consults `proxy-addr` when
  `trust proxy` is set, and this app sets none and never reads `req.ip` or
  `X-Forwarded-For`. **Consequence to remember:** on Render that also means `req.ip`
  is Render's proxy address for every request, so any future IP-based rate limiting
  must first `app.set('trust proxy', 1)` — otherwise all traffic looks like one client.
- **Still open:** 22 dev-only advisories (jest/nodemon/babel chain) which never
  ship; and the **dead Mongoose layer** (`models/*.model.js`,
  `controllers/{drink,order,user}.controller.js`, `middleware/auth.middleware.js`,
  `utils/validators.js`, orphaned `middleware/error.middleware.js`) — removing it
  would let `mongoose`, `jsonwebtoken` and `express-validator` go entirely, but
  `controllers/auth.controller.js` (live) still requires the model, so it needs a
  verified refactor with tests.

### ⚠️ URGENT — live credential committed in git
`drinks-calculator-backend/scripts/reset_test_pwd.js` contains a hardcoded
`postgresql://…:…@…supabase.com:6543/postgres` connection string with the database
password. It is in git history. **Rotate the Supabase database password**, then move
that value to an env var. Business rule already in `.clinerules/01-project`: that
script must never be opened or copied.

### Previous focus — legal pages, manuals, owner flag ✅ (44edf91, pushed)

- **`/api/auth/me` now returns `isOwner`.** Root cause of "company logo change not
  authorized": only *login* set `isOwner`; the auto-login path returned
  `sanitizeUser(user)` without it, so even the real owner was refused after a cold
  start. New pure helper `backend/utils/companyOwner.js` (`resolveIsOwner`, claims
  the company when `owner_id` is null — self-heal) + 15 Jest tests;
  `controllers/auth.controller.js` returns `{...userData, isOwner}`.
- **Privacy Policy and Terms rewritten** (`public/privacy.html`, `terms.html`,
  `privacy.fr.html`, `terms.fr.html`): inline Drink Quick Cal SVG logo, dark-mode
  aware, controller/processor split, sub-processors (Supabase/Render/payment
  operator), retention + 90-day post-closure deletion, security measures, user
  rights, Cameroon Law 2010/012, the Shop's own duties, liability capped at 3 months
  of fees, Douala forum. EN/FR kept in parity.
- **Manuals added**: `docs/USER_MANUAL.md` (service flow end to end: sell, receipt,
  tab, stock, shift, count, offline, subscription) and `docs/ADMIN_MANUAL.md`
  (role matrix + protected owner row, voids with trace, discount approvals, variance
  at cost, cash-up/Z report, credit control, payment reconciliation test vs live,
  security ops, data-protection duties, escalation). English with a French summary.
- Validated: `flutter analyze lib` 0 errors · `flutter test` 293 · backend Jest
  13 suites / 175 tests · i18n parity EN=1114 FR=1114 diff=0 · `node --check` clean.

### Next up (approved or blocked)
1. **Part-payment → remainder onto the customer's tab** (approved with the void set,
   not built): on a partial payment write the paid part as income and the rest as a
   customer ledger entry, in one transaction.
2. **Live money**: the deployed backend is still in TEST mode. Human step — Notch Pay
   Production Mode + `pk_live_`/`sk_live_` on Render, then `NOTCHPAY_REQUIRE_LIVE=true`.
   CamerPay KYC-2 (CNI+NIU) is the recommended rail; Tranzak stays a later co-rail
   only after written answers on its contract red flags.
3. **Two security follow-ups (not applied)**: `Math.random()` reset/join codes
   (5 sites in `server.js`) → `crypto.randomInt`; rate limiting currently covers only
   the most sensitive endpoints.
4. Proposed, not approved: debt-recovery panel, nightly owner WhatsApp summary,
   pre-paid credit. Deferred: multi-company memberships (`user_companies` + switcher).

### Historical context below (older focus, newest first)


## Current focus — Phase 13: live subscriptions — card / MTN / Orange via Notch Pay ✅ (code side)
- **The deployed backend is still in TEST mode**: `/api/subscriptions/notchpay/health`
  reports `mode: "test"` and `liveReady: false` (checked 2026-09-26), because the
  platform Notch Pay account holds test keys. No subscription money can move until
  a human switches that account to Production Mode and sets the live keys on
  Render — the exact steps are in `DEPLOY.md` → *Are we taking REAL money yet?*.
- All three rails now run through Notch Pay. MTN/Orange lock `cm.mtn` / `cm.orange`
  plus `locked_country: CM` (a locked channel must lock its country). **Card** is
  not a documented lockable channel, so `channel: 'card'` locks to the account's
  card channel when it has one and otherwise opens the unlocked checkout page —
  with the app's card provider as a fallback that only runs when no checkout was
  opened (never two charges).
- New: `backend/utils/paymentChannels.js` (pure, 17 Jest tests), `notchpay.listChannels()`
  + `GET /subscriptions/notchpay-channels` (`known` / `supported` per rail),
  channel validation in `notchpay-initiate` (400 on junk, replies `rail` + `channel`),
  `rails` added to `/health`; `lib/utils/payment_channel_helper.dart` (pure, 12 tests)
  and an upgrade sheet built from `PayRail.card|mtn|orange` — a Mobile Money rail the
  account cannot charge is shown disabled with the reason, and `known: false` leaves
  every rail enabled rather than hiding a working one.
- Not verified from here: the card rail against a real live Notch Pay account (no
  live keys available). The unlock path is what makes card work today; once a live
  card channel exists the code locks to it automatically.
- **Security review of the money path** (same task): signatures were verified
  against `JSON.stringify(req.body)` in **four** webhook routes (five sites) —
  HMACs cover the bytes actually sent, so live webhooks would have been rejected.
  `server.js` now keeps the raw body (`express.json({ verify })`), `utils/requestBody.js`
  (`rawBodyOf`) is used by every webhook. Subscriptions also refuse activation on a
  **shortfall** now (`utils/paymentGuard.js`, `paidAmountMatches`; overpayment and
  unknown amounts are allowed, `NOTCHPAY_ALLOW_UNDERPAYMENT=true` opts out), and
  `activatePendingSubscription` returns `{ activated, plan, expiresAt, reason }`
  so a refusal can't be read as an activation. Replay is a no-op (only `pending`
  rows activate); company always comes from the DB row / session.
- Validated: analyze 0 errors · `flutter test` 276 · backend 11 suites / 144 tests
  · i18n parity EN=1075 FR=1075 · `node --check` clean.
- **Test keys are now visible**: the server prints the payment mode on startup and
  `NOTCHPAY_REQUIRE_LIVE=true` (opt-in) makes `notchpay-initiate` answer 503 while
  the keys are test keys — a `pk_test_` key cannot silently hand out paid plans.

## Previous focus — Phase 12: shrinkage / variance detector + a real stock take ✅
- **A stock take exists now**: Inventory → item → **Stock take** (dialog) →
  `updateQuantity(drinkId, counted, performedBy: username)`. The delta is written
  as a movement (`reason: 'stocktake'`, `purchasePriceAtSale` = cost); a matching
  count writes nothing. Before this, quantity could only be added (restock/sales)
  so stock that walked out was invisible.
- **`lib/utils/variance_helper.dart`** (pure, 21 tests): a loss is an outgoing
  movement whose reason is not a sale, valued at COST; totals, unexplained share,
  loss rate vs turnover, rankings by drink/staff/reason, `reasonKey()` → EN/FR.
- **`lib/screens/variance_screen.dart`** (drawer → **Shrinkage**, manager/admin,
  plan-gated on `reports`): 7/30/90 days, KPI card, ranked cards, movement list
  with the unexplained ones flagged.
- Fixed two NUMERIC-as-string crashes in `lib/models/inventory_model.dart`
  (`purchasePrice`, `purchase_price_at_sale`, `selling_price_at_sale`) — they
  silently dropped the inventory/ledger load.
- Validated: analyze 0 errors · `flutter test` 264 · backend 8 suites / 104 tests
  · i18n parity EN=1072 FR=1072. **No schema change, no ops step.**
- Still owed by the human: run `sql/rls_customers.sql` + `sql/rls_shifts.sql` on
  live Supabase (or redeploy — RLS is enabled at boot).

## Next candidates (agreed direction, not started)
- **Loyalty on the customer numbers** (points / buy-10-get-1 / birthdays) — now
  cheap: the ledger, the six-digit numbers and the phone are all in place.
- **Auto purchase order → supplier on WhatsApp** (`forecast_helper` already
  recommends quantities; supplier prices are not stored yet).
- **QR menu → order → pay** (customers, no install) — the network-effect bet,
  needs its own security design (public, token-scoped, rate-limited endpoints).
- **Exact shift attribution** if wanted: stamp `shift_id` on each order (today a
  shift's sales are its time window).

## Previous focus — Phase 11: WhatsApp sharing (statements + Z-report) ✅
- `lib/utils/whatsapp_helper.dart` (pure, 16 tests): `link()` for
  `wa.me/<number>?text=…`, `shareLink()` for the contact picker (no recipient),
  `message()` for the layout (bold title, rows, total, notes, footer),
  `receiptBlock()` (code block so the thermal columns hold), `normalizeNumber()`
  (local → `237…`), `clamp()` (WhatsApp refuses long links: cut on a line
  boundary). `lib/services/whatsapp_service.dart` is the only place that launches
  a URL (`url_launcher`, already a dependency).
- Wired: **customer ledger sheet → Send the statement**; **shift screen →
  Send the Z-report** (dialog action + a chat button on the open shift that sends
  the live numbers). The Z-report goes to `company_phone` when set, otherwise
  WhatsApp asks which contact.
- Message text comes from `t('…')` labels, so nothing is hardcoded and EN/FR stay
  in step (`wa*` keys).
- Validated: analyze 0 errors · `flutter test` 243 passed · backend 8 suites /
  104 tests · i18n parity EN=1042 FR=1042.

## Previous focus — Phase 10: shift handover + cash-up + Z-report ✅
- `shifts` table (one OPEN shift per person via a partial unique index), RLS at
  boot (`sql/rls_shifts.sql`). Staff open a shift with the float in the drawer and
  close it with the cash they counted; the opener may close their own shift and a
  MANAGER (Administrator/owner) may close anyone's — mirrored in
  `backend/utils/shiftMath.js` ↔ `lib/utils/shift_helper.dart`.
- **The Z-report is frozen onto the row when the shift closes**
  (`cash_expected`, `variance`, `order_count`, `total_sales`, `collected`,
  `on_credit`, `payment_breakdown`) so a printed report never changes. Cash
  expected = float + collected − payouts; variance = counted − expected.
- UI: `lib/screens/shift_screen.dart` (open/close, live report, frozen report,
  history), `lib/providers/shift_provider.dart`, drawer entry **Shift / Cash-up**
  for every non-customer role, `shift*` EN/FR keys.
- Routes: `GET /shifts`, `GET /shifts/current`, `POST /shifts`,
  `GET /shifts/:id/summary`, `PATCH /shifts/:id`.
- Validated: analyze 0 errors · `flutter test` 227 passed · backend 8 suites /
  104 tests · i18n parity EN=1034 FR=1034.
- **Ops step still owed by the human**: run `sql/rls_shifts.sql` on live Supabase
  (or redeploy — RLS is enabled at boot). The table is created on the next
  backend start; no app-side migration.
- Also in this stretch: **six-digit customer numbers** (`000001`); an older
  `C-0001` row still blocks the same slot (`{prefix:'C', width:4}` for the old
  style).

## Previous focus — Phase 9 feature A: customer numbers, manager approval, credit ledger ✅
- One **six-digit customer number per company** (`000001`, …), generated by the
  backend (`nextCustomerNumber`, `{prefix: 'C', width: 4}` restores the older
  style) — never by the client. New tables `customers` +
  `customer_credit_transactions`, RLS on at boot (`sql/rls_customers.sql`).
- **The shop's rule is the design**: STAFF enrol a customer (status `pending`),
  only a MANAGER (or Administrator) approves / rejects / blocks / re-limits.
  A manager's own enrolment is approved at once. Credit may only be written
  against an `approved` account; a charge past the credit limit is a 409
  `CREDIT_LIMIT` until a manager confirms the override.
- Mirrored rules: `drinks-calculator-backend/utils/customerApproval.js` (JS,
  testable) ↔ `lib/utils/customer_ledger_helper.dart` (Dart, testable) —
  keep them in step when the rule changes.
- UI: `lib/screens/customer_ledger_screen.dart` (Customers tab sorted by debt +
  Approvals tab as the manager's queue), `lib/providers/customer_provider.dart`
  (caches last known accounts/ledger for offline reading), drawer entry for every
  non-customer role, `cust*` EN/FR keys.
- Validated: `flutter analyze lib` 0 errors · `flutter test` 210 passed ·
  backend 7 suites / 77 tests · i18n parity EN=999 FR=999.
- **Ops step still owed by the human**: run `sql/rls_customers.sql` on the live
  Supabase (or redeploy the backend, which enables RLS at boot) — see DEPLOY.md
  Step 1d. No app-side migration is needed.

## Next up (agreed direction)
B — shift handover + cash-up + Z-report, then C — WhatsApp output, then the
shrinkage/variance detector. Still parked: IoT (Phase 4), full AR (Phase 5),
multi-branch, loyalty.

## Previous focus — three user-reported fixes (all shipped, all validated)
1. **Forecast events really load from the backend now.** Root cause was NOT
   the network: `forecast_events.multiplier` is `NUMERIC(5,2)` and the
   node-postgres driver returns NUMERIC/DECIMAL as a **string** ("1.25"), so
   `(row['multiplier']).toDouble()` in `_applyRows` threw and aborted the whole
   list — the screen then fell back to the (usually empty) local cache.
   Fixed defensively in `lib/screens/forecast_screen.dart` (`_asDouble` helper +
   per-row try/catch so one bad row can't hide the rest) and the API now sends a
   real number (`routes/data.routes.js` GET `/events`). Still-queued offline
   events are merged back in (`_mergePendingEvents`) instead of vanishing.
2. **Profile "Account details" ID** now shows the signed-in **user id**
   (`t('profileUserId')`, new EN/FR key) instead of the company id.
3. **Changing the device PIN requires the login password first**
   (`_confirmDevicePassword` in `profile_screen.dart` → `AuthProvider.verifyPassword`).
   There is no separate "device password" concept in this app; the login
   password stored on the device is the only credential available.
4. **Branding loads at login**, not only after opening the profile: the login
   paths in `auth_provider.dart` and cold start in `main.dart` now warm
   `CompanyBrandingService` (fire-and-forget `unawaited`, never blocks startup),
   and `custom_drawer.dart` calls `load()` (cache-first, server fallback)
   instead of `cached()` so the logo is there on the first drawer open.

Validated 2026-09-24: `flutter analyze lib` 0 errors / 481 issues (baseline),
`flutter test` 191 passed, backend 47 Jest tests passed, `node --check` clean,
i18n parity EN=963 FR=963.

## Previous focus — token efficiency of the Cline setup
- `.clineignore` added at the repo root. It hides `build/` (17,662 files),
  `drinks-calculator-backend/node_modules/` (11,046), `.dart_tool/`, `.git/`,
  native toolchain caches, logs and lockfiles, so the visible tree drops from
  ~29,987 files to roughly 400.
- `.clinerules/` added: `01-project`, `02-conventions`, `03-commands`,
  `04-token-hygiene` (always on) plus `05-backend` and `06-flutter-ui`
  (path-scoped) and `07-memory-bank`.
- `memory-bank/` added (this folder).
- Deleted untracked clutter from the repo root: 13 `flutter_*.log`,
  `code.png` and `pubspec.yaml.backup`.

## Next steps for the human (Cline settings — not code)
- Enable Auto Compact; keep Subagents enabled.
- Lower Max Requests per Task (25–50) to cap runaway loops.
- Use a FREE-tagged or cheap model in Plan mode, stronger model in Act mode.
- Enable read-only auto-approve so approval pauses (extra API round trips) drop.

## How to verify the setup worked
- Start a new task, list the repo root, confirm `build/`, `node_modules/` and
  `.dart_tool/` are absent.
- Compare the starting context token count in the task header with the previous
  ~30k-file behaviour; it should be far smaller.
- Optional: delete `build/` + `.dart_tool/` (1.5 GB, regenerable with
  `flutter pub get`) to speed up every terminal command.

## Open items / risks
- `.clineignore` is marked "deprecate soon" by Cline. Revisit only if a release
  drops it; the suggested replacement is a `PreToolUse` hook, but that is a POSIX
  shell script and awkward on this Windows setup.
- Rules and this Memory Bank are injected/read regularly — keep them short. If a
  file here starts growing into narrative, trim it.

## Product work still open
See `ROADMAP.md` for the authoritative status (Phase 4 IoT sensors, Phase 5 AR
scanning, Phase 8 privacy/branding work).

## Follow-up 2026-09-23 - .clineignore might not be enforced
Diagnosis: the active Cline 4.1.20 `next` bundle has no ignore controller, and a
workspace search returned `.dart_tool` hits despite `.clineignore`. Actions taken:
added `.vscode/settings.json` excludes, deleted `build/`, `.dart_tool/flutter_build` and `.dart_tool/chrome-device`
(regenerable), documented the limitation in `.clinerules/04-token-hygiene.md` and
`memory-bank/techContext.md`.
Open options: pin the bundle (`cline.rollout.bundleOverride` = `legacy`) to restore
`.clineignore`, or add a `PreToolUse` hook (fragile on Windows).

## 2026-10-26 - Data Processing Agreement added (`e676a3d`, app link reverted in `41eaa1d`)
Bilingual DPA served as static HTML beside the other legal pages:
`drinks-calculator-backend/public/dpa.html` + `dpa.fr.html` (12 sections + Annex A
data/purpose/retention, Annex B the measures actually in place, Annex C
sub-processors).
**It is deliberately NOT in the app** - no drawer link, no `ApiConfig` getter, no
i18n key. It is a document handed to a Shop on request (as its section 12 says),
like a contract, so it is not in the consent gate and not part of
`LEGAL_VERSION`. Owner's decision - do not re-add an in-app link.
Verified: `flutter analyze lib` no `error -` lines, `flutter test` **426 passing**,
i18n parity **1479/1479**.
**Still to do:** Annex C says the Supabase project sits "outside Cameroon - the
region chosen when the project was created"; fill in the exact region (Dashboard ->
Settings -> General -> Region) before handing the document to a customer. Not
legal advice - have a lawyer review before relying on it.
`ROADMAP.md` (Phase 16) is still uncommitted.

## 2026-10-28 - NUMERIC bug #3: `orders.tab_amount` wiped the whole order load
Symptom: "Found 128 orders in Supabase" then "Loaded 0 orders", with
`NoSuchMethodError: 'toDouble' ... Receiver: "0.00"` printed per row. Cause:
`orders.tab_amount` is `NUMERIC(12,2)` and node-postgres returns NUMERIC as a
**string** (integer/double columns come back as numbers, which is why
`totalAmount`/`amountPaid`/`balance` looked fine), while `Order.fromJson` did
`(json['tabAmount'] ?? 0).toDouble()`. The throw is inside the per-row loop, so
one unreadable field skipped *every* order.
Fix: new `lib/utils/json_num.dart` (`asDouble`, tolerant of num/String/null/
blank) used for all four money fields in `Order.fromJson` and in
`SupabaseService.saveOrder`'s model->DB mapping; regression test
`test/order_parsing_test.dart` replays the exact failing row.
**Rule: never `.toDouble()` a value that comes from a NUMERIC column — read it
through `asDouble`.** This is the third instance (after
`inventory.purchase_price` and `forecast_events.multiplier`).
Gates: Flutter **432 tests**, `flutter analyze lib` no `error -` lines.
Still open: `inventory_model`, `customer_model` and `container_model` keep their
own private `_asDouble` copies (4 in total) - fold them into `json_num.dart` when
those files are next touched.

## 2026-10-28 - An inventory row must belong to an existing drink (`f5227b9`)
Found in production: **1 orphan** - company 42, drink_id `1792870970398`,
drink_name "music", quantity 0, created 2026-10-24 - with no matching row in
`drinks`. `inventory.drink_id` is a text column with **no foreign key**, so
nothing prevented it. (`drinks_not_stocked` was 0: no drink lacks a stock row.)
Two causes:
1. `DELETE /data/drinks/:id` deleted the drink only, leaving its stock row.
2. There was **no route for deleting a stock line** (only GET/POST/PATCH existed
   on `/inventory`), so `inventory_provider.deleteInventoryItem` called
   `SupabaseService.deleteDrink` - it deleted the DRINK and orphaned the stock
   row. `drink_management_screen._deleteDrink` calls both, so deleting a drink
   fired the drink delete twice and never removed the stock line.
Fixed: the drink delete removes the inventory row **first** (worst case becomes a
drink with no stock row, which the app tolerates via `drinks.current_stock`);
new `DELETE /data/inventory/:drinkId` deletes the stock line only; the app points
at it. `sql/inventory_drink_fk.sql` cleans the orphan and adds
`inventory.drink_id -> drinks(id) ON DELETE CASCADE`.
**The user must still run that script in the Supabase SQL editor** (MCP is
read-only). `inventory_transactions` deliberately keeps no FK - it is the audit
trail and carries its own `drink_name`.
Guards: `tests/inventory_integrity.test.js` (both directions + the SQL script).
Backend **44 suites / 597 tests**, Flutter **432**, no analyzer errors.

## 2026-10-28 - Settings: sandbox / API-key fields removed from the payment section (`26a7435`)
`storage_settings_screen.dart` asked a manager for an MTN and an Orange merchant id,
API key and secret key, offered a per-provider sandbox switch, and had a fake Test
Connection button (2 s delay, then it only checked the fields were non-empty).
CamerPay is the only rail, so all of that is gone: the six credential fields, both
sandbox switches, both test buttons, the test-state fields, both `_testXConnection`
methods, and the leftover NotchPay sync-account-id field.
**Kept deliberately:** the enable/disable switches for MTN MoMo, Orange Money and
Credit Card (both are already gated on `_campayConnected`), the receiving phone field
for each (a business number, not a credential), and the whole CamerPay card.
The `_mtnApiKey` / `_orangeSecretKey` / ... fields and their load+save plumbing stay,
so an existing company keeps its stored values and `utils/momo.js` can still read them.
Gates: `flutter analyze lib` back to the **537-issue baseline**, no `error -` lines;
Flutter **432 tests**.

## 2026-10-28 - CamerPay moved into the Business Payment Settings card (`786c6cf`)
The business payment card now holds the three method toggles (MTN MoMo, Orange Money,
Credit Card) followed by the CamerPay account section, so everything about taking money
is in one place. The standalone `_buildCampaySettingsCard` call was removed from the page
build; the method is unchanged, so it now renders *inside* the card as a Card-in-a-Card
sub-panel (a deliberate choice - flatten it to a plain Column if the owner prefers).
Also removed the receive-payments phone field that sat under the MTN and Orange toggles:
CamerPay carries the whole rail, so a per-provider receiving number was left over from
when those providers were wired up directly. **The toggles now stand alone - the owner's
stated intent: "i just need those toggle should be there that of credit card, mtn and
orange momo".**
`_mtnMerchantPhone` / `_orangeMerchantPhone` and the two phone controllers are still
loaded and saved, so an existing company keeps what it stored (they are still read in
dispose and the load path, so they raise no analyzer warnings).
Gates: **537-issue baseline**, no `error -`; Flutter **432 tests**.

## 2026-10-28 - Credit Card got its own section (`1ba05c5`)
The Credit Card toggle was rendering **inside** the Orange Money container: it was a sibling
of the Orange header Row within that tinted box, so a card payment looked like part of
Orange. It is now its own Container between Orange Money and CamerPay, shaped like the
mobile-money sections (32px badge, title, switch), tinted with `primaryColorValue` and using
a credit-card icon. The new switch uses `activeThumbColor` (the `activeColor` on the Orange
and read-only switches is pre-existing deprecation debt).
**Business Payment Settings is now, in order:** MTN MoMo [toggle] - Orange Money [toggle] -
Credit Card [toggle] - CamerPay account section. The owner's target layout; keep it that way.
Gates: **537-issue baseline**, no `error -`; Flutter **432 tests**.

## 2026-10-28 - Payment column audit (no code change yet, script added in `303e63b`)
Live `companies` payment columns, measured 2026-10-28 (6 companies):
- **MTN:** `mtn_api_key` / `mtn_api_key_encrypted` / `mtn_secret_key` / `mtn_merchant_id` all
  **6/6 non-null**; also `mtn_secret_key_encrypted`, `mtn_merchant_phone`, `mtn_sandbox_mode`.
  Keep `mtn_enabled` (the toggle).
- **Orange:** `orange_api_key` / `orange_secret_key` 6/6; also the `_encrypted` twins,
  `orange_merchant_id`, `orange_merchant_phone`, `orange_sandbox_mode`. Keep `orange_enabled`.
- **Notch Pay:** `notchpay_private_key` 0, `notchpay_public_key` 0, `notchpay_webhook_hash` 0,
  `notchpay_sync_id` 1 - the rail CamerPay replaced.
- **CamerPay:** `campay_token_enc` **0**, `campay_webhook_token` **0** - no company has stored a
  token; the platform token lives in the Render env (`CAMERPAY_TOKEN`,
  `CAMERPAY_WEBHOOK_SECRET`). `campay_token_enc` and `campay_webhook_secret_enc` are already
  encrypted columns, and `COMPANY_SECRET_COLUMNS` (data.routes.js:53) strips secrets from every
  company row returned to a client. `campay_webhook_token` is **plaintext** and is only a routing
  lookup (`WHERE campay_webhook_token = $1`, payment.routes.js:692) - 0 values today.
  `utils/companyPaymentCredentials.js` maps logical names -> columns.
- **Step-2 script written:** `sql/drop_dead_payment_columns.sql`.
- **Blocker before running it:** `pickWritable()` (data.routes.js:126) builds INSERT/UPDATE from
  `WRITABLE['companies']`, and `storage_settings_screen.dart` still sends `mtnApiKey`,
  `mtnSecretKey`, `mtnMerchantId`, `mtnMerchantPhone`, `mtnSandboxMode`, the `orange*` equivalents
  and `notchpaySyncId` on save. Step 1 = trim `WRITABLE['companies']` + `COMPANY_SECRET_COLUMNS`
  and stop writing them in the app; only then drop.
- **RESOLVED 2026-10-28:** `PAYMENT_CREDENTIALS_KEY` **is set on Render** (owner confirmed), so
  per-company CamerPay tokens are encrypted at rest. The vault is AES-256-GCM, authenticated,
  versioned (`v1.<iv>.<tag>.<ct>`) and fails closed: `credentialVault.loadKey()` throws without the
  key and the route answers 400 ("Payment credentials cannot be stored") instead of storing
  plaintext. The key is permanent - a new key cannot decrypt already-stored tokens - so it must
  never be rotated without re-encrypting. Nothing is stored yet anyway (`campay_token_enc` 0/6).
- **Decision (owner, 2026-10-28):** do NOT document `PAYMENT_CREDENTIALS_KEY` in `.env.example` or
  any doc. Render is the only place it should exist and `credentialVault.js` already names the
  variable. A proposed `.env.example` section was rejected - do not re-add it.
- **Authorization (verified, `fcbe3a6`):** `canManagePaymentSettings()` in payment.routes.js allows
  Manager / Administrator / Admin / Owner; both `GET` and `PATCH /payment/campay-settings` answer
  403 for anyone else, with the role resolved from the session by `requireSessionUser` (never
  `req.body`). Live roles: Manager 8, Staff 3, Customer 2, Administrator 1 - so staff and customers
  cannot read or change the credentials. Locked by `tests/payment_settings_authorization.test.js`
  (6 guards). Open decision: the owner asked for "owner + manager"; Administrator/Admin are still
  allowed, and removing them would lock out the single Administrator account.
- **Note:** the app DOES show the blockers in the CamerPay card
  (`storage_settings_screen.dart:2436`, `case 'vault_key_missing'` -> `campayBlockerSecret`, EN+FR).
  The genuinely silent case is only a failed `getCampaySettings()` (offline) returning `null`, where
  `if (campaySettings != null)` skips the blockers entirely and nothing is displayed.

## 2026-10-28 - The legacy payment rail could take money it cannot collect (`9ce9531`)
Found from the Render boot log: "Subscriptions (Notch Pay, legacy): TEST KEYS - real money
will NOT be collected".
**VERIFIED 2026-10-28 - that boot warning is INACCURATE / stale.** `routes/subscriptions.js`
(the subscription initiate route) already refuses unconditionally on test keys:
`if (notchpay.status().mode !== 'live') return res.status(503)...` (line 753), with a comment
stating the Notch Pay rail is **RETIRED**, kept reachable only so a pre-CamerPay app build
"fails loudly instead of being handed a plan nobody paid for - with test keys this always
answers 503, so no plan can be activated through it, free or otherwise". So **no subscription
plan can be activated on a test key**, flag or no flag. The boot line prints the legacy
module's status without reflecting that the route refuses. Do NOT repeat the log's claim.
**The real hole was the till, not subscriptions:** `POST /payment/initiate`
(payment.routes.js) - the Notch Pay path the till falls back to when a company has not
connected CamerPay (`calculator_screen.dart:1075`) - had NO live/test check at all. On test
keys a sale would be started and reported as paid while nothing was collected, and **0 of 6
companies have connected CamerPay**, so that was the default path for every shop.
The guard already existed and was already wired for subscriptions
(`subscriptions.js:1078` checks `paymentGuard.liveKeyRequired()` against the CamerPay
account), and `utils/paymentGuard.js` documents the switch: **off by default**, set
`PAYMENTS_REQUIRE_LIVE=true` (legacy name `NOTCHPAY_REQUIRE_LIVE`) on a production service.
**It was never applied to `POST /payment/initiate`** - the Notch Pay path the till falls
back to when a company has not connected CamerPay (`calculator_screen.dart:1075`). On test
keys a sale would be started and reported as paid while nothing was collected, and **0 of 6
companies have connected CamerPay**, so that was the default path for every shop.
Fixed: the route now refuses with 400 / `success:false` / `code: payment_rail_not_live`
when `liveKeyRequired() && !notchpay.isLive()`. Locked by
`tests/payment_rail_live_guard.test.js`. Backend **46 suites / 606 tests**.
**⚠️ STILL TO DO (operator, not code):** set `PAYMENTS_REQUIRE_LIVE=true` on Render and
redeploy - the code change alone changes nothing. Consequence to accept: with the flag on an
unconnected shop cannot take electronic payments at all (0/6 connected), so its MoMo and
card buttons refuse until it connects CamerPay. Also unverified: whether the subscription
screen still reaches the NotchPay rail, or that boot warning is stale noise from a
still-loaded module - the flag makes it moot either way.
- **Silent-failure spot:** `PaymentService.getCampaySettings()` (payment_service.dart:85-112)
  returns `null` on any error and only prints; the settings screen does
  `if (campaySettings != null) {...}` with no else, so an offline load shows nothing at all.

## 2026-10-28 — Notch Pay removed: CamerPay is the only payment rail (uncommitted)
Phase 5.3 of the CamerPay migration, deferred until the legacy rail could go without stopping
every shop from collecting. The till already refused the legacy path (`campay_not_connected`,
`867501b`), so nothing that worked depended on it.
- **Backend deleted:** `utils/notchpay.js`, `utils/paymentChannels.js`; the six
  `/subscriptions/notchpay-*` routes (initiate / status / webhook / return / health / channels);
  `POST /payment/notchpay-webhook` + `GET /payment/notchpay-return`; the unreachable legacy body
  of `POST /payment/initiate` (the refusal stays — it is what an older app build hits); the Notch
  Pay Sync poll in `GET /payment/status/:id`; the four `notchpay_*` boot ALTERs; `notchpay_sync_id`
  from `GET/PATCH /payment/company-settings`.
- **`GET /payment/health` rewritten for CamerPay:** readiness is now
  `credentials.isConnected(company)` — the company's own account — instead of "platform Notch Pay
  keys + a sync id". The old shape exposed `requiresNotchpaySync` and a `notchpay` block nobody
  could act on. Nothing in the app consumed this route (it reads `/subscriptions/campay/health`).
- **Kept on purpose — the legacy env aliases** in `utils/paymentGuard.js`
  (`NOTCHPAY_REQUIRE_LIVE`, `NOTCHPAY_ALLOW_UNDERPAYMENT`). If Render has
  `NOTCHPAY_REQUIRE_LIVE=true`, deleting the alias would silently switch the live guard OFF —
  the exact hole fixed in `9ce9531`. They are read-only fallbacks; `PAYMENTS_*` is the documented
  name, and the tests pin both.
- **Flutter renamed, not just cleaned:** `notchpayInitiate` → `campayInitiate`, `notchpayStatus`
  → `campayStatus` (they already called CamerPay endpoints). `notchpayChannels` and the whole
  `PayChannelAvailability` class are gone: CamerPay publishes no per-rail list, so the upgrade
  sheet offers all three rails and CamerPay's own page refuses with a reason. The `notchpaySyncId`
  plumbing (helper, settings screen, save payload) and the unused `npSyncAccountId*` /
  `payChannelUnavailable` keys went too. **This also fixed the last failing Flutter test**
  (`company_logo_bytes_test.dart` asserted the removed `notchPayConfigured` getter).
- **`.env.example`** now documents CamerPay (`CAMERPAY_TOKEN`, `CAMERPAY_WEBHOOK_SECRET`,
  `CAMERPAY_ACCOUNT_LIVE`, `PAYMENT_CREDENTIALS_KEY`, `CAMERPAY_FEE_*`, `PAYMENTS_*`) instead of
  `NOTCHPAY_*`; `scripts/check_payments.js` reads `/subscriptions/campay/health`.
- **Gates:** backend **44 suites / 584 tests** (was 46 / 606 — the NotchPay-only suites are gone);
  `node --check` clean; `flutter analyze lib` **537 issues, no `error -`** (the baseline); Flutter
  **428 tests, 0 failures**; i18n **EN=1480 FR=1480**. `RELEASE` → `2026-10-28-notchpay-removed`.
- **Still on the human:** run `sql/drop_notchpay_columns.sql` (now unblocked — nothing reads those
  columns) and set `PAYMENTS_REQUIRE_LIVE=true` on Render. `sql/drop_dead_payment_columns.sql`
  stays blocked: the app still writes the MTN/Orange credential keys.

## 2026-10-28 — Per-company B2C readiness: the owner can see who is ready (uncommitted)
The per-company B2C flow was already built (each company connects its **own** CamerPay account; the
till charges through it, and the fee is the bar's cost — never booked as revenue). What was missing
was any way to answer "which of my companies can actually collect?" without opening six Settings
screens — and **0 of 6 are connected**, so every till currently refuses electronic payment with
`campay_not_connected` and the sale must be cash.
- **`utils/companyReadiness.js`** (pure, 11 tests): reshapes `credentials.healthFor` into one admin
  row — booleans, `blockers`, and **one `nextStep`** in the order the work has to happen
  (`set_vault_key` → `connect_token` → `add_webhook_secret` → `ready`). A missing server vault key
  is reported before a company is asked to connect, so nobody is sent in a circle.
- **`GET /api/admin/campay-readiness`** (`verifyAdmin`, the same gate as the admin panel): one row
  per company plus a summary. **Deliberately secret-free** — it does not even read
  `campay_webhook_token`, and returns no token, no masked token and no webhook URL (that URL's path
  *is* the company's opaque webhook token: a manager may copy it from its own card, a list must not
  carry it). Locked by tests.
- **`scripts/campay_readiness.js`** (`npm run campay:readiness`): an HTTP client for that route — no
  database, no credentials in the file, password from `ADMIN_PASSWORD` in the environment (never an
  argument: it would land in the shell history and `ps`). Exit 1 while anything blocks collection, so
  it works as a post-deploy ops check. Verified: no password → clear message + exit 1; wrong password
  → `HTTP 404: Route not found` (the route is not deployed yet).
- **`.env.example` fixed:** it had **two** `ADMIN_PASSWORD` entries and one claimed a fallback to
  `admin123`, which does not exist — `server.js` DISABLES the override unless the value is ≥ 12
  characters. Now one documented entry.
- Gates: backend **45 suites / 595 tests** (+1 suite / +11); `node --check` clean on all four files;
  no `lib/` change, so the Flutter gates are untouched.
- **Next (not done):** an app-side admin tab rendering the same list, and the onboarding itself —
  each company must create its own CamerPay token and finish KYC. `PAYMENT_CREDENTIALS_KEY` is
  already set on Render (owner, 2026-10-28), so no platform-side blocker remains; `platformState()`
  reports that key once so the script shows it instead of anyone assuming it.

## 2026-10-29 — Pushed `7f65df9`; Render needed a manual deploy (landed 22:02:50Z) ✅
- `git push origin master` succeeded (`1ac2bb6..7f65df9`); `origin/master` = `7f65df9`.
- **The deploy did not happen**, proven three ways: `GET /api/admin/campay-readiness` → **404** (the
  new route), `GET /api/subscriptions/notchpay/health` → **200** (a route this commit DELETES is
  still being served), and `/health` still reports `release: 2026-10-24-rls-lockdown` while
  `uptimeSeconds` climbed steadily (412 → 1023s, no restart). `DEPLOY.md` documents `uptimeSeconds`
  as the deploy signal, so that is the method to reuse.
- **Why: this repo has NO webhooks and NO CI.** `GET /repos/mdksako-eng/drink-quick-back-end/hooks`
  returns `[]` (verified with Node; an earlier PowerShell "1" was the `@($null).Count` trap), and
  there is no `.github/`. So **"push = deploy" is NOT automatic here** — Render is either deployed
  manually, no longer connected to GitHub, or its Auto-Deploy is set to "After CI checks pass"
  (which can never fire with no CI). Check: Render → service `drink-quick-cal-kja1` → **Events**,
  and Settings → **Build & Deploy** → Auto-Deploy.
- **The branch is correct — do not chase it:** `origin/main` (HEAD 2026-08-29) is a stale parallel
  line with no `drinks-calculator-backend/` and no `release` in its `/health`, while the deployed
  payload has master's exact shape. Render serves `master`. (`main` IS the remote's default branch,
  which is its own hygiene problem: a fresh clone or PR lands on the wrong history.)
- **Not triggerable from here:** no Render credentials, no deploy-hook URL recorded anywhere in the
  repo (searched `*.md`/`*.txt`/`*.json`/`*.yml`), and no webhook to redeliver. `render.yaml` is
  stale — it names a different service and still lists `NOTCHPAY_*` / Flutterwave /
  `PLATFORM_MTN_*` vars (cleanup candidate).
- **After the deploy, verify:** `/health` → `2026-10-28-notchpay-removed`, and
  `/api/admin/campay-readiness` → 401 (admin-gated) instead of 404.
- **RESOLVED the same day (startedAt 22:02:50Z):** the owner triggered the deploy from the Render
  dashboard and it landed. Verified live: `release=2026-10-28-notchpay-removed` with a fresh
  `uptimeSeconds`; the new `/api/admin/campay-readiness` answers **401** (gated, live); the deleted
  `/api/subscriptions/notchpay/health` answers **404**. Post-deploy regression check (the removal cut
  ~280 lines out of `subscriptions.js`): `/api/subscriptions/campay/health` still 200 with
  `liveReady: true`, the rewritten `/api/payment/health` 200, `/api/payment/initiate` 401 (route
  intact and session-gated), `/api/ping` pong. **Conclusion: deploys here are MANUAL — a push alone
  does nothing** (no webhook, no CI).

## 2026-10-29 — The plaintext MTN/Orange payment credentials are out of the code
The last known security liability in the payment area: `companies` held 6/6 non-null plaintext
`mtn_api_key` / `mtn_secret_key` / `orange_*` rows for a rail that no longer exists, and
`sql/drop_dead_payment_columns.sql` was blocked because the app wrote those keys and the backend
read them.
- **Every read and write is gone.** `GET /payment/company-settings` selects the four switches only
  (and no longer masks anything — there is no provider secret left to mask); `PATCH` accepts the
  switches only; the legacy MTN auto-verification in `GET /payment/status/:id` is removed;
  `/payment/health` no longer reports a per-rail sandbox mode; `/api/data/company` and the public
  company profile stop selecting the six columns; `WRITABLE['company_payment_settings']` is trimmed;
  and `/company/payment-credentials` is deleted with its columns.
- **The app plumbing is gone too:** the credential fields, controllers, prefs cache, load and save
  maps in `storage_settings_screen.dart` + `payment_helper.dart`, plus 13 dead `st_*` i18n keys
  (EN **and** FR) that only labelled the removed fields. The toggles (MTN / Orange / Card) stay.
- **The purge stays on purpose:** both files still `remove()` / `deleteEncryptedApiKey()` the old
  pref names, because a device that ran an older build may still hold a plaintext provider key.
- **`COMPANY_SECRET_COLUMNS` now strips the CamerPay secrets** (`campay_token_enc`,
  `campay_webhook_secret_enc`, `campay_webhook_token`): one route returns `SELECT *` for a company,
  so that was a real leak of ciphertext + the webhook path token.
- **Two dead legacy endpoints removed, one of them a security fix:** `POST /payment/orange-webhook`
  was **unauthenticated** and could mark any transaction `completed` from the request body alone (no
  signature check). It and `/payment/orange-return` went with the rail; the generic
  `/payment/webhook` (HMAC-verified) stays.
- **`isMaskedOrEmpty` now recognises `****`** as well as the legacy bullets, so the mask this API
  emits for a stored CamerPay token can never be written back as a secret.
- **Guard:** `tests/payment_credentials_removed.test.js` (7 tests) fails if a dropped column name
  reappears in `server.js` / `payment.routes.js` / `data.routes.js`, or if the app starts sending the
  camelCase fields again.
- **Order matters:** run `sql/drop_dead_payment_columns.sql` only AFTER this is deployed — the old
  build still SELECTs those columns, so dropping them first would break company settings.
- Gates: backend **46 suites / 603 tests** (+1 suite / +7); `flutter analyze lib` 537 issues, no
  `error -`; Flutter **428 tests**; i18n **EN=1466 FR=1466**.

## 2026-10-29 — Changing a company's CamerPay credential needs the password, is audited, and emails the owner
The gap left by the credential review: `PATCH /payment/campay-settings` wrote no audit row (unlike plan
changes, unblock/delete and refunds) and had no second check — so a manager session found on an unlocked
till could replace the company's token and send every future collection to another account.
- **Re-authentication.** Storing or replacing the TOKEN now requires the actor's own password
  (`currentPassword`), verified with bcrypt exactly like login — including the legacy plaintext fallback
  that upgrades the hash on success, so there is still only one hashing path. Bounded by its own
  `createQueue(2)` (bcrypt is CPU-heavy) and rate-limited to 5 tries / 15 min per user; a success resets
  the counter. Only a token needs this: rotating the webhook token or flipping the switch moves no money,
  and demanding a password on every toggle would just train people to type it without thinking.
- **Audit.** Every change writes an `audit_log` row (`company.payment_credential`) with the actor, the
  target and a description built by the pure `utils/credentialChange.js` — booleans only, never the
  values, because the audit log is read by people.
- **Owner notice.** Replacing the token or the webhook secret emails the company owner: who did it, when,
  what changed, and what to do if it was not them. Fire-and-forget, because a dead mailer must not block a
  legitimate fix — the audit row is the durable record.
- **App.** Both CamerPay save paths (the main Save button and the card's own save) prompt for the password
  when a token is typed; cancelling sends nothing. The three refusal codes
  (`password_required` / `invalid_password` / `too_many_attempts`) are shown as our own translated
  sentences — 7 new keys in EN and FR.
- Guard: `tests/payment_credential_change.test.js` (12 tests) pins the three controls, the bcrypt-only
  rule, the machine codes, and that the audit detail and the notice carry no values.
- Gates: backend **47 suites / 615 tests** (+1 suite / +12); `flutter analyze lib` 537 issues, no
  `error -`; Flutter **428 tests**; i18n **EN=1473 FR=1473**.

## 2026-10-29 — Drawer navigation: a truthful highlight, real grouping, a search box, one role rule
The drawer was a 20-entry list whose highlight was hardcoded to Dashboard, with no grouping (the keys
`menuManagement` and `menuSupport` existed but were used **zero** times), no search, and two role
conventions in one file (`role == 'manager'` lowercase and `user.role == 'Manager'` capitalised).
- **The highlight is now derived, not asserted.** `DrawerMenu` is told which screen it is open on
  (`DrawerScreen`) and `_buildItem` computes `isSelected = screen == currentScreen`. The old code
  passed `isActive: true` once, for Dashboard. Tapping the entry you are already on now just closes the
  drawer instead of pushing a second copy of the same screen.
- **Correcting an earlier claim of mine:** I first said the hardcoded highlight "lies" while you are on
  Inventory. That was wrong — `CustomDrawer` is mounted in exactly ONE place
  (`calculator_screen.dart:2081`), so the drawer can only be opened from the calculator, where
  Dashboard *is* the right highlight. The real gap is that the drawer is **hub-only**: from Settings you
  must go back to the calculator before you can open it. Making the highlight a mechanism is still right
  (it cannot go stale, and mounting the drawer elsewhere is now a one-liner), but the hub-only
  limitation is the bigger item and is **not** done.
- **Grouping** (`utils/drawer_navigation.dart`, pure + tested): Daily (what you touch while serving) →
  Reports (read-only analysis) → Setup (configuration and billing) → Manager → Admin → Support. The two
  dead keys are now the Reports and Support headers and `menuSetup` is new; a section with no visible
  entry is not rendered at all.
- **Search** at the top of the menu: filters by translated label, case- and accent-insensitively
  (`foldForSearch`), with a "nothing matches" line instead of an empty list.
- **One role rule**: `StaffPermissions.normalizeRole` + `isAdminRole` / `isManagerRole` /
  `isOwnerRole` / `isStaffRole` / `isCustomerRole`. The drawer and the shell both use them; no raw role
  string is compared in the drawer any more. `isManagerRole` accepts `'Owner'` too — the backend already
  treats it as a manager (`payment.routes.js`, `twoFactor.js`), so a hand-set Owner row no longer hides
  the manager entries.
- **Also fixed**: two hardcoded English section headers (`'MANAGEMENT'`, `'SUPPORT'`) the i18n sweeps
  had missed.
- The drawer shell went from 1301 to 902 lines; the menu (with its search state) is its own widget.
- Gates: `flutter analyze lib` **535 issues** (was 537), no `error -`; Flutter **443 tests** (15 new);
  i18n **EN=1477 FR=1477**. Backend untouched.
- **Still open (reported, not done):** mounting the drawer on the top-level screens so two of them can
  be reached without returning to the calculator, and a `NavigationRail` for tablet widths.

## 2026-10-29 — Design tokens, piloted on the drawer (deliberately NOT a "morphism")
The app had grown 27 gradients, 33 one-off box shadows and 194 hand-picked `withValues(alpha:)` values,
so the drawer, the cards, the dialogs and the till each expressed "a surface" slightly differently.
Consistency — not a new style — is what reads as polish, and unlike blur it costs nothing on the GPU.
- **Decision: Material 3 + restrained soft depth. No glassmorphism, no neumorphism, no claymorphism.**
  This is a till used in daylight on low-end Android (`minSdk = flutter.minSdkVersion`) with money
  figures a cashier must read unambiguously: `BackdropFilter` (0 uses today) re-blurs every frame over a
  scrolling list, neumorphism encodes state with shadow alone and loses contrast, and claymorphism fights
  a data-dense UI. Glass stays an option for 2–3 *static* surfaces later (drawer header, a floating bar,
  dialogs).
- **`lib/theme/app_theme.dart`** (new): radius scale (8/12/16/pill), spacing scale, alpha steps, two
  theme-aware shadow levels, the single `AppBrand.surface` gradient with its on-surface text colours,
  `AppText.itemLabel`/`sectionLabel`, and `AppRoleBadge` (pure, so the amber/orange/blue chip colours are
  unit tested instead of being nested ternaries inside a build method).
- **The drawer is the pilot**: the header uses the one brand surface, the role chip and sync pill use
  tokens, and a selected entry uses M3's `secondaryContainer` / `onSecondaryContainer` role instead of a
  10 % tint of the primary — which was all but invisible in dark mode. Selection is still signalled three
  ways (bold + accent bar + tinted panel), never by colour alone.
- **Both themes had to be fixed to make that role real**: `ColorScheme.light`/`dark` in `main.dart` set
  only `primary` and `secondary`, so `secondaryContainer` was Flutter's default lavender. Both now derive
  it from the brand colour — a pale tint with dark brand text in light, a deep tint with light text in
  dark.
- Guards: `test/app_theme_test.dart` (11 tests) pins the scales, the gradient, the badge colours and — as
  a source guard — that the drawer keeps using the tokens and the old `withValues(alpha: 0.1)` selection
  tint does not come back. `test/drawer_menu_test.dart` gained a dark-mode test asserting the selected
  label uses the theme's `onSecondaryContainer`.
- Gates: `flutter analyze lib` **535 issues**, no `error -` (unchanged); Flutter **455 tests** (+12);
  i18n unchanged (no new keys).
- **Next if the direction is approved:** roll the tokens out screen by screen (cards, dialogs, the till),
  and optionally a glass treatment on 2–3 static surfaces only.
