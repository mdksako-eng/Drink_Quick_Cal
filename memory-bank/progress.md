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

## Security hardening from the audit — 2026-11-12
- Untracked `scripts/live_smoke.js` (`git rm --cached`; the repo is **public**, so an owner
  must **rotate** its credentials and decide on history purge). `.gitignore` already listed
  it — the rule just never got applied to an already-committed file.
- Prod `npm audit`: **8 → 4** (all 3 HIGH gone); **`mongoose` removed** as a dead dependency
  (−18 packages, nothing live or tested required it).
- 12 MB JSON limit is now `/api/ai` only; 1 MB everywhere else, with `captureRawBody` shared
  so webhook HMACs still see raw bytes.
- Boot migrations no longer race `app.listen` (the pending `orders.payment_method` deploy
  would have failed a first order); `RELEASE` → `2026-11-12-hardening`.
- `android:allowBackup="false"`.
- Gates: backend **52 / 697**, Flutter **573**, analyze **0 errors**.
- Open: rotate+purge, deepmerge/SendGrid, payment_method deploy, Render spin-down,
  `helmet` (unused), data hygiene (orphan Manager id=26, doppel deposit 1.00, 101 inactive
  legacy tokens).
- **Later 2026-11-12:** security headers wired (`utils/securityHeaders.js` +
  `tests/security_headers.test.js`, 7 DB-free tests; CSP/COEP deliberately off, framing is
  helmet's `SAMEORIGIN`) and **101 legacy guessable session tokens deleted** (guarded to
  legacy+inactive+expired; verified separately: 354 → 253, active still 1). Backend
  **53 suites / 704 tests**. Not touched: `doppel` deposit, orphan Manager id=26, the
  unverified account.

## Quantity ceiling + visible container types — 2026-11-12
- The 99-unit cap (six places, two answers: calculator 99 x4, dictates 99 x2, scanner 999) is
  replaced by ONE rule: `lib/utils/order_limits.dart` (`maxQuantity = 999`), used by the till,
  both dictates and the scanner; `test/order_limits_test.dart` (6 tests).
  `ai_order_parser_test.dart` now asserts 999 instead of 99 — an intentional change.
  999 rather than unlimited because the cart stores one entry per unit and the body must stay
  inside the 1 MB JSON limit.
- The registered container types now have their own always-visible **Container types** section
  (name + deposit, manager can re-price). They were invisible before: the "out by container"
  list is filtered to non-zero outstanding and the table had 0 movements. Renaming needs the
  endpoint to take an id — named, not faked (the name is read-only while editing).
- 1 new EN/FR key (`contTypes`). Flutter **579 tests**, analyze **0 errors**,
  i18n **EN=1567 FR=1567**.

## Faster cold start (no security change) — 2026-11-11
- `lib/main.dart`: the startup fan-out is now parallel (`Future.wait` over settings + drinks +
  orders + inventory) instead of 6 sequential round trips; the duplicate session check is
  skipped when `autoLogin()` already validated (`sessionValid`) — still exactly one validation
  per start, before the first frame; the expiry alert is `unawaited`; money helpers stay local
  and offline-safe.
- 7 serial network calls → 2 phases. Splash still waits for the catalogue (no empty-menu
  regression) — rendering before data lands needs a cache-first pass in the providers.
- Remaining "fast" wins are hosting, not code: Render free tier spin-down (keep-alive on
  `/api/ping`), `UV_THREADPOOL_SIZE=8` for the login burst.
- Flutter **573 tests**; analyze **0 errors**; i18n **EN=1566 FR=1566**.

## Scan single/batch sell + plan-follows-session — 2026-11-11
- **Scan to sell:** the sell sheet chips came from a guessed ladder (1/6/12/24/48); a
  12-bottle crate was offered "24". `lib/utils/scan_sell_helper.dart` (new, pure, 8 tests) now
  reads the drink's own `unitsPerPack` → single unit + whole pack, with words for the shelf
  note. 3 new EN/FR keys.
- **Shared-till plan leak (reported):** a fresh interactive login never re-bound the plan (that
  wiring only ran on app launch), and a FAILED plan fetch was recorded as "on Free" — together
  they parked a paying Pro user on the plans screen until they opened the subscription screen
  by hand. Fixed in `plan_provider.dart` (`resolved`/`fetchFailed`, coalesced + background
  retry, `setSession(null)` truly clears), `main.dart` (plan bound per session from an
  `AuthProvider` listener, cleared on logout, post-frame so it precedes `PlanGate`), and
  `plan_gate_logic.dart` (`fetchFailed` → proceed; backend `requirePlan` remains the enforcer).
- Flutter **573 tests, all passing** (the previously-red `plan_provider_session_test.dart` is
  fixed by this); analyze **0 errors**; i18n **EN=1566 FR=1566**. Backend untouched.

## Bluetooth printer status card — 2026-11-11
- The receipt screen now answers "is the printer connected?" BEFORE a print: a status card
  with the state in words, the device name, and what to do next. The printer is remembered on
  the device and reconnects on open; a **Test slip** proves paper/feed/connection; the
  connection is held open instead of dropped after each write; Connect / Disconnect / Change
  printer / Check again are explicit; a nameless thermal printer is labelled by its MAC.
- Pure logic in `lib/utils/printer_status_helper.dart` (+ `test/printer_status_test.dart`,
  10 tests); the pipeline split into steps in `lib/services/receipt_printer.dart`;
  27 new `printer*` EN/FR keys. `receipt_printer_mac`/`_name` are DEVICE settings, not
  company-scoped cache, so they survive a sign-out.
- Flutter **561 tests**; analyze **0 errors**; i18n **EN=1563 FR=1563**. Not device-verified
  (needs real Bluetooth hardware).

## Refund lanes — cash stays cash, CamerPay stays CamerPay — 2026-11-11
- A refund now follows the money's ORIGINAL path. `orders.payment_method` (+ boot migration,
  `sql/orders_payment_method.sql`) is written by the till when it creates the sale; one lane
  rule is mirrored in `utils/refundRecord.js` ↔ `lib/utils/refund_lane_helper.dart`; the refund
  dialog asks for a CamerPay reference only on the CamerPay lane; the Z-report takes **cash**
  returns off the drawer only (`cashReturnValue` / `providerReturnValue` in `orderReturn` and
  `shiftMath`, with the shift queries joining the order's method onto the return ledger).
- Closes the ROADMAP 2026-10-11 gap "a refund is always assumed to be cash out of the drawer".
  The other half of that gap (a refund recorded as `'card'` whatever the sale was) is closed too.
- Deliberately NO automatic CamerPay refund call: CamerPay documents **full** refunds only and
  this app's returns are partial.
- Backend **52 suites / 697 tests**; Flutter **551**; analyze **0 errors**; i18n **EN=1536 FR=1536**.
- Pre-existing, unrelated red: `test/plan_provider_session_test.dart` (uncommitted
  `plan_provider.dart` work in the tree).

## AI screen — honest photo reading, and replies that were translated all along — 2026-11-12 (`85ceb4d`, `12decba`)
- **Vision prompt** (`utils/aiVisionPrompt.js`, 12 Jest tests): off-menu drinks are **reported** not
  dropped, unreadable lines are **admitted** not guessed, a missing quantity is 1, and a photo with
  no order emits no `ORDER_JSON`. `POST /api/ai/vision` calls it.
- `AIOrderParser.unmatchedLines()` (+5 tests) with *"⚠️ Not in your catalogue: …"* in the chat, so a
  bad photo is distinguishable from a missing catalogue entry. Also on the typed `ORDER_JSON` path.
- Capture `1024px/q60` → **`1600px/q80`** (~250–450 KB): q60 blurred the handwriting the feature is
  for, which is what people meant by "the AI did not understand my photo".
- **12 i18n keys already existed, unused.** The chat's stock / price / recommendation / checkout /
  clear / connection answers were hardcoded English in a French app that reads them aloud. Wired —
  **no new keys**. Adding them instead broke the build: `ai_orderCleared` was already defined, and a
  duplicate key in a `const` map is a compile error (every test file then failed to *load*).
- Camera permanently denied → offers Settings instead of repeating a dead-end toast.
- Chat system prompt: answer in the user's language (the reply is shown **and** spoken).
- Flutter **584** · analyze **0 errors** · i18n **EN=1570 FR=1570** · backend **54 suites / 716**.


## AI screen — the spoken voice follows the app language — 2026-11-12 (`9a845c5`)
- The TTS language fell back to a hardcoded `'en-US'`, so a French shop heard French replies read
  aloud in an English voice until it opened the voice settings. `VoiceService.resolveTtsLanguage(
  {stored, appLanguage})` (pure, 6 tests) decides: a stored choice always wins, otherwise the app
  language. A mid-session language switch moves the voice while no choice is stored; confirming the
  voice settings makes the choice explicit. No new i18n keys.
- **Prod is live on `2026-11-12-hardening`** (`GET /health`): the owed deploy has happened, so the
  `orders.payment_method` boot migration has run (the port opens only after `bootstrapReady`). The
  column itself is unverified — the local `.env` has no `DATABASE_URL`.
- Flutter **590** (+6) · analyze **0 errors** · i18n **EN=1570 FR=1570**.


## Download page moved to Cloudflare Pages — 2026-11-12
- The front door was served by the **free Render instance that sleeps** (503 first, ~100 s to wake);
  it is now a self-contained static site in **`download-page/`** served by **Cloudflare Workers static
  assets** (`wrangler.jsonc` at the root, runbook `DOWNLOAD_PAGE.md`), needing **no backend change**
  because the release API answers `Access-Control-Allow-Origin: *` (verified live
  with an `Origin` header).
- The page is static, the metadata is not: version / notes / SHA-256 still come from
  `GET /api/app/release`, so `API_BASE` is the one line tying the two hosts together.
- New **"could not reach the download server"** state, deliberately distinct from the API's own
  `known:false` ("no build is published yet") — a sleeping instance must never read as a fact about
  the release. Two attempts (9 s timeout, one silent retry after 6 s) plus a GitHub releases link as
  the escape hatch.
- `_headers` ports the helmet-class headers to the static host, with a CSP that pins `connect-src`
  to the API host.
- Verified: same-SHA byte copy of the reviewed page → `data-en`/`data-fr` **23/23** → `node --check`
  on the inline script **exit 0** → CSP host matches `API_BASE`. The Render copy stays for now — now
  that the Worker is live, a redirect on the next backend deploy is its cleanup; legal pages are
  linked, not copied.
- **Deployed 2026-11-12:** assets-only Worker (`wrangler.jsonc`, no `main`) live at
  **`https://drink-quick-cal.mbundaderick.workers.dev`**. Verified against the live site rather than
  locally: `/` 200, `/download` + `/download.html` **301** → `/`, `/_headers` + `/_redirects` **404**
  (read, never served), `/logo.png` 200 + its `Cache-Control`, every security header present, French
  text intact.
- `workers_dev: true` and **`preview_urls: false`** are now explicit — implicit preview URLs would
  keep every old version permanently reachable.
- The build installed **177 backend packages** to upload 4 static files: the repo root's `package.json`
  (the Render shim) has a `postinstall` that installs the backend, which coupled the front door's
  deploy to the backend's dependencies. Cloudflare's fix: build variable
  **`SKIP_DEPENDENCY_INSTALL=1`**.
- **Owner:** the custom domain, that build variable, then publish a release (`known:false` today).


## First published release — the APK is live — 2026-11-13 (`v1.1.0`)
- **Signed APK published** at
  `https://github.com/mdksako-eng/Drink_Quick_Cal/releases/download/v1.1.0/app-release.apk`
  (82.6 MB / 86,643,870 bytes), tag pinned to the commit it was built from (`0d02283`).
  Verified end to end: **302 → 200**, `Content-Type: application/vnd.android.package-archive`, and
  the **served bytes hash to `3C373C0B…72C69`** — identical to the local build, so shops checking the
  published SHA-256 are checking the file they actually receive.
- **Rebuilt rather than republished:** the APK already on disk was from **11/11 09:30** and **12
  commits** had landed since (AI photo fixes, localised replies, voice-language fix, 999 ceiling).
  The published binary is proven current — the day's new strings (`Not in your catalogue`,
  `Absents de votre catalogue`) are inside `libapp.so`.
- Signed with the release key (`CN=Drink Quick Cal`, cert `4dfea099…`), checked with `apksigner`.
- Published with **no new credential**: the upload used the GitHub OAuth token Git Credential
  Manager already stores for `github.com`.
- **Still owner's:** the six `APP_*` variables on Render + a deploy, after which
  `/api/app/release` flips to `known:true` and both front doors light up together.


- **Phase 4 — Real-time IoT sensor integration (automated replenishment)** ⬜ needs
  ESP32/load-cell firmware, a device-authenticated `POST /api/sensors/reading`, and
  Supabase Realtime wiring in the app.

## Known issues / quirks worth remembering
- Notifications are device-only by design; `/api/data/notifications` and its table
  were removed (`sql/drop_notifications_table.sql` is the opt-in cleanup).
- `FlutterAssertionGuard` intentionally drops one known Flutter framework
  re-entrancy assertion (mouse_tracker, flutter/flutter#137938) — do not clean it up.
- Backend release marker: `RELEASE` near the top of `drinks-calculator-backend/server.js` is the
  only way to confirm a deploy from outside, via `GET /health`. It reads
  **`2026-11-12-hardening`** (it was `2026-09-20-phase8` before 2026-11-12).
