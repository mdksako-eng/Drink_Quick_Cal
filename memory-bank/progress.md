# Progress

Mirrors `ROADMAP.md`, which is authoritative. Keep this short.

## Delivered
- **Phase 1 — Manager dashboard analytics** ✅ `manager_dashboard.dart`,
  `charts.dart`, `analytics_helper.dart`, `analytics_model.dart`: revenue, orders,
  items sold, average order, popular items, peak hours, category mix, 7/30/90-day
  ranges, EN/FR keys.
- **Phase 2 — Predictive analytics / demand forecasting** ✅ `forecast_model.dart`,
  `forecast_helper.dart`, `holidays.dart`, `forecast_screen.dart`: moving average +
  weekly seasonality, holiday/event multipliers, recommended order quantities,
  optional Groq AI summary.
- **Phase 3 — Receipt printing / sharing** ✅ `receipt_printer.dart` (self-contained
  ESC/POS + Bluetooth), `receipt_print_screen.dart` (58/80 mm preview), Android
  Bluetooth permissions, `print_bluetooth_thermal` dependency.
- **Phase 5 — Barcode/QR scanning** 🟡 MVP shipped (`mobile_scanner`,
  `barcode_service.dart`, `scanner_screen.dart`, `qr_flutter` labels, scan →
  calculator via `OrderBridge`); full AR recognition still planned.
- **Phase 6 — Hardening, billing gate, alerts, reporting** ✅ batch dates now persist
  (`buildDrinkInsertPayload` / `mapDrinkRow` in `supabase_service.dart`),
  `forecast_events` RLS, notifications device-only, `staffPermissions.js` +
  `staff_permissions.dart` (co-managers cannot edit the owner), subscription
  `PlanGate` with per-company "Continue on Free", pro staff scanning, 30-day expiry
  alerts joined with the forecast, professional inventory export (PDF/Excel/CSV with
  per-section checkboxes), `FlutterAssertionGuard` tames the MouseTracker
  re-entrancy assertion.
- **Phase 8 — Shared-device privacy, branding, role-aware profile** — per-company
  cache wipe on logout (`session_data_cleaner.dart`), company logo everywhere
  including invoices/exports (`company_logo_bytes.dart`), smart phone entry
  (`phone_helper.dart`), role-aware `profile_screen.dart`, working compact mode,
  owner-only data management (`owner_permissions.dart`). Full list in `ROADMAP.md`.
- **Tooling (2026-09-23)** — added `.clineignore`, `.clinerules/` and `memory-bank/`;
  removed root clutter (13 `flutter_*.log`, `code.png`, `pubspec.yaml.backup`).
- **Order corrections (2026-10-10)** — the calculator's rollbacks stopped using the untracked
  `is_active` PATCH. New `POST /api/data/orders/:id/cancel` records who/why without moving stock, the
  Z-report excludes inactive rows and lists them as corrections (`utils/orderVoid.isInactive`), a
  refused multi-line sale puts back the lines it had already deducted, and the invoice card's
  button/dialog/toast follow one tested decision (`lib/utils/order_action_helper.dart`), and the
  Z-report dialog + WhatsApp report now show the corrections line the API always computed. Backend
  **23 suites / 343 tests**; Flutter **306 tests**; i18n EN=1171 FR=1171.
- **Re-invoice repaired (2026-10-10)** — "Edit & Re-invoice" rebuilt cart lines with fabricated ids, so
  the stock commit always failed (a partial return was impossible); lines now come from the real
  catalogue drink by name (`utils/invoice_import_helper.dart`, 10 tests) and the action is
  manager-gated like a void. Flutter **316 tests**; i18n EN=1176 FR=1176.
- **Returns (2026-10-11)** — "1 of 2 comes back" in one action, without void + re-invoice. New
  manager-only `POST /api/data/orders/:id/returns` + `GET`, capped by the movements ledger (a unit
  can never be refunded twice), stock back through the guarded `applyStockDelta`, and a Z-report
  **Returns** line + **Net sales** with the refund taken off `expectedCash`. Backend
  **24 suites / 371 tests**; Flutter **326 tests**; i18n EN=1193 FR=1193.
- **Returns for whole sales (2026-10-11)** — a whole crate sale of 24 units already worked (the ceiling
  is per drink and the sale deducts one unit per entry), so the gap was the UI: the return dialog now
  takes a **typed quantity**, an **"All left"** per line and **"Return everything left"**
  (`OrderReturnHelper.allRemaining`, 4 more tests). Bar-only copy swept out of the return hint, both
  manuals, the four legal-page taglines and `projectbrief.md`. Flutter **330 tests**;
  i18n EN=1195 FR=1195.
- **Notch Pay removed (2026-10-28)** — CamerPay is the only rail. `utils/notchpay.js` +
  `utils/paymentChannels.js`, the six `/subscriptions/notchpay-*` routes, the `/payment/notchpay-*`
  webhook/return pair, the unreachable legacy `/payment/initiate` body, the Notch Pay Sync poll and
  the `notchpay_*` boot columns are gone; `GET /payment/health` now reports CamerPay readiness. The
  app renamed `notchpayInitiate/Status` → `campayInitiate/Status`, dropped `PayChannelAvailability`
  and the `notchpaySyncId` plumbing — which also fixed the last failing Flutter test. The
  `NOTCHPAY_*` env aliases stay readable on purpose (dropping them would switch the live guard off).
  Backend **44 suites / 584 tests**; Flutter **428 tests, 0 failures**; i18n **EN=1480 FR=1480**;
  analyze 0 errors. Human step: run `sql/drop_notchpay_columns.sql`.
- **Per-company CamerPay readiness (2026-10-28)** — `utils/companyReadiness.js` (one ordered
  `nextStep` per company), admin-only `GET /api/admin/campay-readiness` (secret-free by
  construction: it never even reads the webhook token) and `npm run campay:readiness` for the owner.
  `.env.example`'s duplicated/incorrect `ADMIN_PASSWORD` note fixed (there is no `admin123`
  fallback). Backend **45 suites / 595 tests**. The onboarding itself stays human: each company
  creates its own CamerPay token and completes KYC.
- **Push ≠ deploy (2026-10-29)** — `7f65df9` needed a **manual** Render deploy; a push alone did
  nothing (the repo has **no webhooks and no CI**). Once triggered it landed clean: `release` →
  `2026-10-28-notchpay-removed`, the deleted `notchpay/health` route → 404, the new admin route →
  401, and `/subscriptions/campay/health` still 200 with `liveReady: true` (no regression from
  cutting ~280 lines out of `subscriptions.js`). Verify any future deploy with `/health` `release`
  plus a restarting `uptimeSeconds`, per `DEPLOY.md`.
- **Plaintext payment credentials dropped (2026-10-29)** — every read/write of the MTN/Orange
  credential columns is gone (backend **and** app), the dead `/company/payment-credentials` endpoint
  and the **unauthenticated** `orange-webhook` are deleted, `COMPANY_SECRET_COLUMNS` now strips the
  CamerPay secrets, and `sql/drop_dead_payment_columns.sql` is ready — but only **after** the deploy
  lands. Guarded by `tests/payment_credentials_removed.test.js`. Backend **46 suites / 603 tests**;
  Flutter **428 tests**; i18n **EN=1466 FR=1466**.
- **CamerPay credential changes are now protected (2026-10-29)** — replacing the token needs the actor's
  password again (bcrypt, rate-limited, own auth queue), every change writes an `audit_log` row, and the
  company owner is emailed (fire-and-forget). The app prompts for the password on both save paths and
  translates the refusal codes. Guarded by `tests/payment_credential_change.test.js`. Backend
  **47 suites / 615 tests**; Flutter **428 tests**; i18n **EN=1473 FR=1473**.
- **Drawer navigation (2026-10-29)** — the highlight is derived from the screen the drawer is opened on
  (it was hardcoded to Dashboard), the 20 entries are grouped into Daily / Reports / Setup / Manager /
  Admin / Support (the two dead i18n keys are used now), the menu has an accent-insensitive search box,
  and every role check goes through `StaffPermissions` instead of two conventions. Two hardcoded English
  section headers are translated. The drawer shell is 902 lines (was 1301); the menu lives in
  `widgets/drawer_menu.dart`. `flutter analyze lib` 535 issues, no errors; Flutter **443 tests**;
  i18n **EN=1477 FR=1477**. Known limitation: the drawer is still mounted only on the calculator.
- **Design tokens, piloted on the drawer (2026-10-29)** — `lib/theme/app_theme.dart` (radius/spacing/alpha
  scales, two theme-aware shadow levels, the one `AppBrand` surface, `AppText`, `AppRoleBadge`). The
  drawer header and entries now use them, a selected entry uses M3's `secondaryContainer` role instead of
  a 10 % primary tint (invisible in dark mode), and both themes in `main.dart` now derive that role from
  the brand colour. Decision recorded: **no glassmorphism / neumorphism / claymorphism** — low-end
  Android in daylight, and blur over a scrolling till is dropped frames. `flutter analyze lib` 535
  issues, no errors; Flutter **455 tests**.

## Phase 18 — Recipe / pour cost (costing only) — 2026-11-01
- **Landed**: `drink_recipes` table (+ RLS/REVOKE, `sql/rls_recipes.sql`), pure `utils/recipeCosting.js`
  (**22 Jest tests**), 5 manager-only routes gated by `requirePlan(['pro'])`, and the app side:
  `utils/recipe_cost_helper.dart` (**13 Flutter tests**), `models/recipe_model.dart`,
  `providers/recipe_provider.dart`, `widgets/recipe_editor_dialog.dart`, entry from the drink form.
- **Design**: the cost is computed from the ingredients' current purchase prices on every read and never
  stored; a missing price is counted, never treated as 0. A recipe is replaced in one statement so a failure
  leaves the old recipe intact.
- **Boundary**: a recipe does not move stock (variance and the Z-report untouched) — ingredient deduction is
  Phase B.
- **Bonus fix**: receiving a delivery now refreshes `drinks.purchase_price`, which nothing did before, so cost
  figures stop going stale.
- Gates: backend **643 tests** / 48 suites, Flutter **498 tests**, analyze **489 issues / 0 errors**,
  i18n **EN=1515 FR=1515**.

## Recipe follow-ons — report screen, Phase B stock, per-shop target — 2026-11-01
- **Landed** (`e90619b`, `4d26cca`, `9bd63e7`):
  1. `lib/screens/pour_cost_report_screen.dart` — `GET /recipes/costing` finally has a screen: shop-wide
     pour cost **weighted by units sold**, every drink worst-first, and the caveat instead of a flattering
     margin when a price is missing.
  2. **Phase B** — a sale takes the recipe's whole-unit ingredients (`utils/recipeStock.js`, **9 Jest
     tests**) through the same atomic primitive a sale uses; ledger reason `'recipe'`, which the shrinkage
     report classifies as neither a sale nor a loss.
  3. `companies.target_pour_cost` + `PATCH /recipes/target` — the shop's own target; refused with 400 when
     unusable, NULL meaning the built-in default.
- **Decision of record**: stock stays a **whole-unit ledger**. A fractional pour is reported
  (`notTracked`), never deducted — the business is a whole-unit retailer, and 0.05 in an int column would
  be a wrong number.
- Gates: backend **49 suites / 655 tests**, Flutter **522 tests**, `flutter analyze lib` **0 errors**,
  i18n **EN=1524 FR=1524**.
- **Owner action**: the `target_pour_cost` column is added by the boot `ALTER`, so it exists after the next
  **manual** Render deploy; until then the read falls back to 20 % and a save is best-effort.

## New-version notice — 2026-11-10 (`d9e6796`)
- **Landed**: public `GET /api/app/release` (env-driven; unconfigured ⇒ `known:false` ⇒ silent), pure
  `utils/appRelease.js` (**13 Jest tests**), and the app side: `utils/app_update_helper.dart`,
  `providers/app_update_provider.dart`, `widgets/update_notice_host.dart` (`home:` inside the Navigator,
  dialog, "Later" always available).
- **Decision of record**: the installed version is `AppConstants.appVersion` (+ new `appBuild`) — the app's
  single declared source of truth. `test/app_info_test.dart` rejects a version literal anywhere else in
  `lib/`, and it failed this feature's first draft, which had its own copy.
- Gates: backend **50 suites / 666 tests**, Flutter **539 tests**, `flutter analyze lib` **0 errors**,
  i18n **EN=1529 FR=1529**.
- **Owner action**: `/api/app/release` plus `companies.target_pour_cost` appear only with the next
  **manual** Render deploy; a push does not deploy, `GET /health`'s `RELEASE` marker proves it.
- **Queued**: release-APK signing (`key.properties` + `build.gradle.kts`), a download page in
  `drinks-calculator-backend/public/`, Windows readiness, a repo `SECURITY.md`.

## Signed APK + download page — 2026-11-10
- **Landed**: `android/app/build.gradle.kts` signs from `android/key.properties`
  (`key.properties.example` template) and **refuses** a release build without it unless
  `-PallowDebugSigning=true` — measured reason: `flutter build apk` swallows Gradle `logger.warn`,
  so only an `error()` is visible. Both branches built and checked with `apksigner verify`.
- `drinks-calculator-backend/public/download.html` (public, bilingual, reads `/api/app/release`);
  `APP_APK_SHA256` added to the announcement (64 hex chars, validated).
- New runbook **`RELEASE.md`** (the APK counterpart to `DEPLOY.md`).
- **Migration of record**: the debug-signed builds already shipped must be UNINSTALLED before the
  first signed release will install; only on-phone state is lost.
- Gates: backend **50 suites / 668 tests**, Flutter **539**, analyze **0 errors**, APK 82.3 MB.

## Audit round — 3 defects fixed — 2026-11-10 (`d829e22`)
- Notice dialog no longer stacks (double notify + mandatory re-arm); download page no longer
  leaves a dead disabled button and hides it correctly (`.btn[hidden]`); the pour-cost report
  builds cards lazily instead of constructing all of them every build.
- Method note: the page defects were found by **running** its script (now committed as `tests/app_release_page.test.js`),
  not by reading; the jank test was rewritten once after the first version proved vacuous.
- `variance_screen.dart` has the same eager `ListView(children:)` pattern — named, not changed.

## Offline banner + security-question reset — 2026-11-10
- Offline banner could not appear: `_isChecking` stuck true (no try/catch around the connectivity
  call; early `return` on a non-200 `/health`; swallowed timeout). Fixed — a failed `/health` IS
  offline now. Mounted in the Scaffold body of containers/purchasing (right), wraps the whole
  calculator in main.dart (draws over its AppBar) — see activeContext for the decision of record.
- "Reset by security" was a **stub** in `AuthProvider.resetPassword` (returned false, no request) and
  had **no backend route**. Now implemented end to end with a pure `utils/securityAnswers.js`
  (empty stored answer refuses; wrong-answer lock reuses `password_reset_requests`), and both reset
  routes revoke sessions. Backend **52 suites / 686 tests**; Flutter **540**; analyze **0 errors**.

## Not started
- **Phase 4 — Real-time IoT sensor integration (automated replenishment)** ⬜ needs
  ESP32/load-cell firmware, a device-authenticated `POST /api/sensors/reading`, and
  Supabase Realtime wiring in the app.

## Known issues / quirks worth remembering
- Notifications are device-only by design; `/api/data/notifications` and its table
  were removed (`sql/drop_notifications_table.sql` is the opt-in cleanup).
- `FlutterAssertionGuard` intentionally drops one known Flutter framework
  re-entrancy assertion (mouse_tracker, flutter/flutter#137938) — do not clean it up.
- Backend release marker: `RELEASE = '2026-09-20-phase8'` near the top of
  `drinks-calculator-backend/server.js`; bump it to confirm a deploy from outside
  via `GET /health`.
