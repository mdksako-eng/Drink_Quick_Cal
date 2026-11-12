# Drink Quick Cal — Feature Roadmap (5 Features)

A phased plan for the requested features, ordered by value-vs-risk.

> Status legend: ✅ done · ⬜ planned

---

## Phase 1 — Manager Dashboard Analytics (charts, popular items, peak hours) ✅

**Value:** High · **Risk:** Low · **Hardware:** none

Everything is computed client-side from data already in memory (`OrderProvider.orderHistory`).

### Delivered
- `lib/models/analytics_model.dart` — `AnalyticsSnapshot`, `PopularItem`, `CategorySlice`.
- `lib/utils/analytics_helper.dart` — `computeAnalytics(orders, startDate, endDate)`.
- `lib/widgets/charts.dart` — dependency-free chart widgets:
  - `HourlyBarChart` (24h vertical bars — peak hours)
  - `RevenueLineChart` (CustomPaint line/area — revenue trend)
  - `DonutChart` (donut + legend — sales by category)
- `lib/screens/manager_dashboard.dart` — KPI cards (revenue, orders, items sold, avg order), popular items (ranked bars), peak hours, revenue trend, category mix, 7/30/90-day range selector.
- Drawer entry (`analyticsMenu`) for Manager + Admin roles.
- EN/FR keys added to `i18n.dart`.

### Validation
- `flutter analyze lib` → 0 errors
- EN/FR key parity check → equal, no missing

---

## Phase 2 — Predictive Analytics / Demand Forecasting ✅

**Value:** High · **Risk:** Medium · **Hardware:** none

### Delivered
- `lib/models/forecast_model.dart` — `ForecastItem`, `EventDay`, `ForecastResult`.
- `lib/utils/forecast_helper.dart` — `computeForecast()` (moving average + weekly seasonality + event multipliers).
- `lib/utils/holidays.dart` — static holiday calendar + `upcomingStaticEvents()`.
- `lib/screens/forecast_screen.dart` — forecast list, recommended orders, trend/confidence, custom events, optional AI summary (Groq).
- Drawer entry (`forecastMenu`) for Manager + Admin; EN/FR keys.

### Approach
1. **Deterministic engine (offline, no AI cost):**
   - Moving average + weekly seasonality per drink from `InventoryProvider.transactions` / `OrderProvider.orderHistory`.
   - Holiday/event calendar with demand multipliers (static holiday table + user-defined events).
   - Output: forecasted demand per drink → recommended order quantity vs `minStockLevel`.
2. **Optional AI layer:** feed the historical summary + upcoming events to the existing `GroqService` (`/api/ai/chat`) for a natural-language forecast.

### Files (planned)
- `lib/models/forecast_model.dart` — `ForecastItem { drinkName, forecastQty, recommendedOrder, confidence, trend }`.
- `lib/utils/forecast_helper.dart` — `computeForecast(...)`.
- `lib/utils/holidays.dart` — holiday table + event CRUD (SharedPreferences).
- `lib/screens/forecast_screen.dart` — forecast list, order recommendations, AI summary.
- Drawer entry + `i18n.dart` keys.

### Notes
- Keep the forecast local/offline first; add `/api/analytics/forecast` only if server-side aggregation is desired.

---

## Phase 3 — Receipt Printing / Sharing (thermal printer) ✅

**Value:** Medium · **Risk:** Medium (platform) · **Hardware:** thermal printer (optional)

### Delivered
- `lib/services/receipt_printer.dart` — self-contained ESC/POS generator + Bluetooth printing.
- `lib/screens/receipt_print_screen.dart` — 58/80mm preview, Bluetooth print, text share/save.
- `responsive_invoice.dart` — receipt (thermal) action wired from the invoice.
- `android/app/src/main/AndroidManifest.xml` — Bluetooth permissions.
- `print_bluetooth_thermal` dependency + EN/FR keys.

### Approach
1. **Sharing** — already done via `share_plus` (PDF). Add "share as text" fallback.
2. **Thermal (ESC/POS)** — new native packages:
   - `esc_pos_utils` (byte encoding, 58mm/80mm)
   - `print_bluetooth_thermal` (Bluetooth discovery/printing; Android/iOS)
   - `permission_handler` (already present) for Bluetooth runtime permission.
3. Render a monochrome receipt from `Order` data (same source as `responsive_invoice.dart`).
4. Fall back to the existing PDF `printing` flow on Windows/web where thermal isn't supported.

### Files (planned)
- `lib/services/receipt_printer.dart` — ESC/POS builder + printer discovery + print/save.
- `lib/screens/receipt_print_screen.dart` — printer list + preview + print button.
- Wiring into `responsive_invoice.dart` (new "Thermal" button).
- `android/app/src/main/AndroidManifest.xml` — Bluetooth permissions.
- `i18n.dart` keys.

### Notes
- Android requires runtime Bluetooth + (API 31+) `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN`.
- iOS supports AirPrint natively via `printing`; dedicated thermal apps use Bluetooth (MFi/LAN) printers.

---

## Phase 4 — Real-time IoT Sensor Integration (automated replenishment) ⬜

**Value:** Medium · **Risk:** High (hardware + backend) · **Hardware:** ESP32/Arduino + weight/load-cell sensor

### Approach (3 layers)
1. **Firmware (separate repo):** ESP32 reads load cell → reports weight over WiFi (MQTT or HTTP POST).
2. **Backend:**
   - `POST /api/sensors/reading` (device-authenticated) → upsert `sensor_readings`.
   - Publish change to **Supabase Realtime**.
3. **App:**
   - Subscribe to Realtime (`SupabaseService` already has Realtime infra + an `inventory` channel pattern).
   - Map sensor → `InventoryItem` via a `device_id`/`drink_id` mapping.
   - Live-update quantity + trigger existing `NotificationService.showLowStock/OutOfStock`.

### Files (planned)
- Backend: `routes/sensors.js` (or inline in `server.js`), `sql/sensor_tables.sql`.
- App: `lib/models/sensor_model.dart`, `lib/services/sensor_service.dart`, Realtime channel in `SupabaseService`, mapping UI in `inventory_screen.dart` / `storage_settings_screen.dart`.
- `ApiConfig` endpoints.

### Notes
- Requires real hardware for end-to-end testing; the app + backend integration layer can be built and unit-tested independently.
- Recommend MQTT (Mosquitto/EMQX) if scaling to many devices; HTTP is fine for a pilot.

---

## Phase 5 — AR Scanning (barcode/QR MVP → full AR later) 🟡

**Value:** Medium · **Risk:** Medium → High (full AR) · **Hardware:** camera + printed codes

### Delivered (MVP)
- `mobile_scanner` dependency + `CAMERA` permission.
- `drink_model.dart` — added `barcode` field.
- `lib/services/barcode_service.dart` — scan → drink/inventory matching.
- `lib/screens/scanner_screen.dart` — camera preview, scan overlay, torch/camera toggle, detail sheet with quick restock.
- Drawer entry (`scanMenu`) for drink-managing roles; EN/FR keys.

### How the MVP works
1. **Barcode/QR scan → item detail:**
   - Add `mobile_scanner` package + camera permission (`permission_handler` already present).
   - Scan a label → match SKU/barcode to a `Drink`/`InventoryItem` → open live stock detail + restock/count actions.
2. **Print labels:** generate QR/barcode labels from the app (ties into Phase 3 printing).

### Full AR (later, high effort)
- `arcore_flutter_plugin` / `arkit_flutter_plugin` + custom object-detection ML models per product (e.g. `tflite_flutter`).
- Research-level effort; only pursue after the barcode MVP validates demand.

### Files (planned)
- `lib/screens/scanner_screen.dart` (camera + scan + result sheet).
- `lib/services/barcode_service.dart`.
- `drink_model.dart` — add `barcode` field.
- `i18n.dart` keys, `pubspec.yaml` deps, Android/iOS permissions.

---

## Suggested sequencing
1 → 2 → 3 → 4 → 5 (each phase independently shippable).

---

## Phase 6 — Hardening, billing gate, alerts & reporting ✅

**Value:** High · **Risk:** Medium (touches login flow, security and exports)

Requested in one batch; shipped as nine independently validated changes.

### Delivered
1. **Drink batch dates actually persist** (`lib/services/supabase_service.dart`).
   `production_date`, `expiry_date` and `unit_kind` were never sent to
   `/api/data/drinks` and were dropped again when reading the rows back, so the
   dates looked lost. Payload building and row mapping are now pure, unit-tested
   helpers (`buildDrinkInsertPayload`, `buildDrinkUpdatePayload`, `mapDrinkRow`,
   `dateOnly`); the same fix stops `image_url` from being wiped on save/edit.
2. **`forecast_events` RLS** — created without row level security, so the anon
   key could read/forge company events. RLS + `REVOKE ALL … FROM anon,
   authenticated` is applied at boot and via `sql/rls_forecast_events.sql`
   (`scripts/apply_forecast_rls.js`); the lockdown scripts cover the newer tables.
3. **Notifications are device-only** — the `/api/data/notifications` routes, the
   table creation and every client sync path were removed; history lives in
   SharedPreferences. `sql/drop_notifications_table.sql` is the opt-in cleanup.
4. **Co-managers cannot edit the owner** — `PUT /api/auth/update-staff/:id` now
   refuses unless the caller is the owner or an Administrator, and the owner can
   never be demoted out of the Manager role. Rules live in
   `utils/staffPermissions.js` (backend) and `lib/utils/staff_permissions.dart`
   (UI), both unit tested.
5. **Subscription gate** — `PlanGate` resolves the plan right after login: an
   active plan goes straight through, free/none/expired plans open the
   subscription screen, and **Continue on Free** is remembered per company (a
   lapsed paid plan re-opens the gate). `lib/utils/plan_gate_logic.dart` holds the
   decision table.
6. **Pro staff barcode scanning** — the drawer exposes the (Pro) scanner to
   Staff, the scan sheet gained a quantity stepper plus *Send to calculator*
   (via `OrderBridge`), and stock-management actions stay manager/admin only.
7. **30-day expiry alerts joined with the demand forecast** —
   `computeExpiryAlerts()` pairs each batch date with its expected demand and
   suggested order; `ExpiryAlertService` raises the alert once per batch per day
   and the forecast screen shows an *Expiring soon* banner. The AI assistant and
   the forecast AI summary both receive the expiring-stock context and are told to
   push those batches first.
8. **Professional inventory export** — `lib/utils/inventory_report_files.dart`
   builds a presentation-ready PDF (company name, period, KPI boxes, two bar
   charts, stock/low-stock/expiry/movement tables, page numbers), a multi-sheet
   Excel workbook and a CSV. The export dialog offers a **checkbox per section**,
   the company name comes from `CompanyNameHelper`, and all labels are EN/FR.
9. **MouseTracker assertion tamed** — `FlutterAssertionGuard` drops only the
   known framework re-entrancy assertion
   (`mouse_tracker.dart … !_debugDuringDeviceUpdate`, flutter/flutter#137938) and
   counts it; a periodic rebuild storm in the connectivity banner was removed too.
   The same guard now prints a **one-per-location pointer** for real layout
   failures ("RenderBox was not laid out", `box.dart:2251`) so the offending
   `file:line` is visible instead of drowning in per-frame repeats.
10. **In-app drink pictures** — the image field in Drink Management has an upload
    button (camera/gallery) that stores the picture in the public Supabase Storage
    bucket `drink-images` and fills the URL automatically
    (`lib/services/drink_image_service.dart`, bucket + policies in
    `sql/storage_drink_images.sql`: 5 MB, images only, no overwrite/delete).
11. **AI assistant image + voice** — a captured photo is shown inside the
    conversation (Gemini-style) and survives a restart on native, spoken commands
    are persisted like typed ones (mic badge), and the pending-order button is
    labelled **Proceed**.
12. **Scan restock asks the quantity** — "Add stock" opens a dialog (quantity
    field with ±, +1/+pack shortcuts, validation, resulting total) instead of
    silently adding a whole pack.

## Phase 8 — Shared-device privacy, branding everywhere, role-aware profile

1. **Company data no longer leaks between sessions** — logout, a forced logout and
   a customer sign-in now wipe every company-scoped cache (name, email, phone,
   address, currency, payment switches, logo) via
   `lib/services/session_data_cleaner.dart`. The logo cache is keyed **per
   company** (`company_logo_url_<id>`), so a customer or another shop's staff can
   never see the previous company's branding or currency.
2. **Logo reaches every manager and staff member** — `CompanyBrandingService.load`
   falls back to the company record on the server (not just the local cache), so
   the logo appears on any device the moment it is uploaded.
3. **Logo on invoices and exports** — the inventory PDF, the profit/analytics PDF
   and the invoice PDF embed the real image (`lib/utils/company_logo_bytes.dart`
   downloads + caches it, and simply omits it when offline); Excel and CSV carry
   the company name and logo link. A missing logo never breaks an export.
4. **Smart phone entry** — `lib/utils/phone_helper.dart` caps the field to the
   country's real digit count (Cameroon 9 starting with 6/2/3/8, Nigeria 10),
   groups digits as you type and returns localized errors. Used by the sign-up form
   and by the company/merchant phone fields in Settings.
5. **Role-aware profile screen** — `lib/screens/profile_screen.dart`, reachable from
   the drawer for every role: branding header with the company logo, an access
   summary that differs per role (customer / staff / manager / owner manager /
   admin), account details, activity stats (drinks, stock, low stock, today's
   orders) that are hidden for customers, PIN management and logout.
6. **Compact mode is real** — it was stored and notified but never applied;
   `ThemeProvider.compactMode` now drives `visualDensity`, tap-target size, list
   tile density, input padding, card margins and a 0.92 text scale in both themes.
7. **Saving no longer looks like loading** — Storage Settings used `_isLoading` for
   both, so pressing *Save* replaced the screen with a "Loading settings…" spinner.
   Saving now has its own `_isSaving` state (button spinner, disabled while
   running) and the loading text is localized.
8. **Owner-only administration** — `lib/utils/owner_permissions.dart` (unit tested)
   gates **Data management** and the **company logo** to the owner manager or a
   platform admin: a co-manager cannot clear company data or re-brand the shop. The
   backend self-heals companies whose `owner_id` was never set by letting the first
   Manager who signs in claim it.
9. **Payments honesty** — `scripts/check_payments.js` reports whether real money can
   be collected, and the subscription screen shows a **Test mode** banner while the
   platform keys are still sandbox keys.
10. **`.gitignore`** — the IDE-generated `devtools_options.yaml` is ignored.

### Validation
- `flutter analyze lib` → 0 errors
- `flutter test` → 110 passing (drink batch dates, staff permissions, plan gate,
  expiry alerts, inventory report builders, assertion guard)
- `npx jest` (backend) → 6 suites / 43 tests passing (schema hardening, staff
  permissions, orders staff-name, atomic inventory, payment mode, smoke)

---

## Phase 9 — Customer numbers, manager approval & the credit ledger (tabs) ✅

### Delivered
- **Customer accounts ("customer numbers")** — a `customers` table with one
  six-digit number per company (`000001`, `000002`, …). The number is generated
  by the backend (`nextCustomerNumber`) and never accepted from the client, so it
  can never be reused or forged. An older-style row (`C-0001`) still blocks the
  same digits.
- **The manager holds the final say** — STAFF enrol a customer
  (`POST /api/data/customers`, status `pending`); only a Manager (or a platform
  Administrator) may approve, reject, block or re-limit the account
  (`PATCH /api/data/customers/:id` → 403 for staff). A manager's own enrolment is
  approved immediately, because they are the approver.
- **Credit ledger** — `customer_credit_transactions` records every `charge`
  (credit given) and every `payment`, with the staff member who wrote it. A
  balance is always `charged − paid`, computed from the ledger, never stored
  twice.
- **Credit limit** — a charge past the manager's limit is refused (409,
  `code: CREDIT_LIMIT`) unless a manager confirms the override. A staff
  enrolment can never carry a limit of its own.
- **Offline** — the last known accounts + ledger are cached locally, so a till
  with no network still shows who owes what; writing needs the server, because
  credit is money.
- **UI** — `lib/screens/customer_ledger_screen.dart`: a **Customers** tab
  (approved accounts, biggest debt first) and an **Approvals** tab (the manager's
  queue, decision menu only for them). Drawer entry for every non-customer role;
  `cust*` EN/FR keys.

### Files
- `drinks-calculator-backend/utils/customerApproval.js` + `tests/customer_approval.test.js`
- `drinks-calculator-backend/sql/rls_customers.sql`, boot DDL + RLS in `server.js`
- `drinks-calculator-backend/routes/data.routes.js` — 5 routes
- `lib/models/customer_model.dart`, `lib/utils/customer_ledger_helper.dart`
  + `test/customer_ledger_test.dart`, `lib/providers/customer_provider.dart`,
  `lib/screens/customer_ledger_screen.dart`, `lib/config/api_config.dart`,
  `lib/services/supabase_service.dart`, `lib/widgets/custom_drawer.dart`,
  `lib/main.dart`, `lib/utils/i18n.dart`

### Validation
- `flutter analyze lib` → 0 errors
- `flutter test` → 210 passing (19 new credit-ledger tests)
- `npm --prefix drinks-calculator-backend test` → 7 suites / 77 tests passing
- i18n parity → EN=999 FR=999

---

## Phase 10 — Shift handover, cash-up & Z-report ✅

### Delivered
- **A shift is a till session** — `shifts` table, one OPEN shift per person (a
  partial unique index prevents two tills from being merged by accident). RLS is
  enabled at boot and the client roles are revoked (`sql/rls_shifts.sql`).
- **Open / close** — a staff member opens a shift with the float that is in the
  drawer and closes it with the cash they counted. The staff member who opened a
  shift may close it; a MANAGER (or the platform Administrator / company owner)
  may close anyone's — mirrored in `utils/shiftMath.js` and
  `lib/utils/shift_helper.dart`. One open shift per person.
- **The Z-report is frozen** — it is computed from the orders inside the shift
  window and stored on the row when the shift closes (`cash_expected`,
  `variance`, `order_count`, `total_sales`, `collected`, `on_credit`,
  `payment_breakdown`), so a report that was printed once never changes.
  Cash expected = **opening float + money collected − cash paid out**; the
  variance is counted − expected (negative = the till is short).
- **Money-honest wording** — a tab is not cash: only collected money counts in
  the drawer, and the screen says so.
- **History** — every past shift with its sales and variance (green balanced,
  red short, orange over).
- **UI** — `lib/screens/shift_screen.dart` (open/close dialogs, live Z-report,
  the frozen report after closing, history), `lib/providers/shift_provider.dart`,
  drawer entry **Shift / Cash-up** for every non-customer role, `shift*` EN/FR
  keys.

### Files
- `drinks-calculator-backend/utils/shiftMath.js` + `tests/shift_math.test.js`
- `drinks-calculator-backend/sql/rls_shifts.sql`, boot DDL + RLS in `server.js`
- `drinks-calculator-backend/routes/data.routes.js` — 5 routes
  (`GET /shifts`, `GET /shifts/current`, `POST /shifts`,
  `GET /shifts/:id/summary`, `PATCH /shifts/:id`)
- `lib/models/shift_model.dart`, `lib/utils/shift_helper.dart`
  + `test/shift_helper_test.dart`, `lib/providers/shift_provider.dart`,
  `lib/screens/shift_screen.dart`, `lib/config/api_config.dart`,
  `lib/services/supabase_service.dart`, `lib/widgets/custom_drawer.dart`,
  `lib/main.dart`, `lib/utils/i18n.dart`

### Validation
- `flutter analyze lib` → 0 errors
- `flutter test` → 227 passing (17 new shift / cash-up tests)
- `npm --prefix drinks-calculator-backend test` → 8 suites / 104 tests passing
- i18n parity → EN=1034 FR=1034

### Also in this stretch
- **Six-digit customer numbers** (`000001`): `nextCustomerNumber` pads to six
  digits with no prefix, and compares numbers by their digits, so an older
  `C-0001` row still blocks `000001`. `{prefix: 'C', width: 4}` restores the old
  style.

---

## Phase 11 — WhatsApp-native sharing (statements, Z-report, receipts) ✅

### Delivered
- **`lib/utils/whatsapp_helper.dart`** (pure, 16 tests):
  - `link(phone, message)` → `https://wa.me/<number>?text=…`;
    `shareLink(message)` → the contact picker, for when there is no recipient.
  - `normalizeNumber()` — `6 99 12 34 56`, `0699123456` and `+237 699 123 456`
    all become `237699123456`; a number that already carries another country
    code is left alone.
  - `message()` — bold title, optional subtitle, label/value rows, a total
    block, notes and an italic footer. Optional rows with an empty value drop
    out, so a report never shows a dangling label.
  - `receiptBlock()` — a receipt goes inside a code block so WhatsApp keeps the
    columns of the thermal layout.
  - `clamp()` — WhatsApp refuses very long links, so an oversized message is cut
    on a **line boundary** and marked with an ellipsis (the full report is always
    in the app / PDF).
- **`lib/services/whatsapp_service.dart`** — the I/O boundary (`url_launcher`),
  so screens never launch URLs themselves: `send(phone:, message:)`,
  `share(message:)`, `hasNumber()` (a button is disabled instead of failing after
  the tap).
- **Where it is wired**
  - **Customer ledger sheet → Send the statement** (charges, payments, balance,
    to the customer's number; disabled when no number is on file).
  - **Shift screen** — the Z-report dialog has **Send the Z-report**, and the open
    shift has a chat button that sends the live numbers *before* cashing up. It
    goes to the shop's own number (`company_phone`) when set, otherwise WhatsApp
    asks which contact to send it to.
- No new dependency (`url_launcher` was already in `pubspec.yaml`), and the
  message text is built from `t('…')` labels, so the helper stays pure and the
  wording stays bilingual (`wa*` keys).

### Files
- `lib/utils/whatsapp_helper.dart` + `test/whatsapp_helper_test.dart`
- `lib/services/whatsapp_service.dart`
- `lib/screens/customer_ledger_screen.dart`, `lib/screens/shift_screen.dart`,
  `lib/utils/i18n.dart`

### Validation
- `flutter analyze lib` → 0 errors
- `flutter test` → 243 passing (16 new WhatsApp tests)
- i18n parity → EN=1042 FR=1042

### Next (agreed order)
The shrinkage / variance detector — shipped as Phase 12 below.

---

## Phase 12 — Shrinkage / variance detector (+ a real stock take) ✅

### Delivered
- **A stock take finally exists.** Inventory → tap an item → **Stock take** asks
  for the quantity actually counted on the shelf. Until now the quantity could
  only be *added* (restock, sales), so stock that walked out never had a moment
  where it could be noticed — and only a physical count can reveal it.
- **The silent overwrite is gone.** `InventoryProvider.updateQuantity` used to
  change the number and record nothing, which is exactly where shrinkage hid. It
  now writes the difference as a movement (`reason: stocktake`, valued at cost)
  carrying the staff member's name, and writes nothing at all when the count
  matches the books (a correct count leaves no noise).
- **`lib/utils/variance_helper.dart`** (pure, 21 tests): a movement is a LOSS
  when it is outgoing and its reason is not a sale; losses are valued at **cost**
  (never at retail — otherwise the number is inflated), sales at the selling
  price. It returns totals, the unexplained share (blank or unknown reasons),
  the loss rate against turnover, and rankings by drink / staff / reason, plus
  `reasonKey()` mapping movement reasons to EN/FR labels.
- **`lib/screens/variance_screen.dart`** (drawer → **Shrinkage**, manager/admin,
  plan-gated on `reports`): 7/30/90-day selector, a KPI card (lost value, units,
  share of turnover, biggest single loss), an orange "Unexplained" line when
  losses have no reason, three ranked cards with share bars, and the movements
  themselves with the unexplained ones flagged for a conversation.
- **Two NUMERIC-parsing bugs fixed on the way** (`lib/models/inventory_model.dart`):
  `purchasePrice`, `purchase_price_at_sale` and `selling_price_at_sale` are
  NUMERIC columns and reach the app as strings (`"800.00"`); `.toDouble()` on
  them threw and dropped the whole inventory/ledger load. Parsing is now tolerant
  — which is what makes the price history usable for this report at all.

### Files
- `lib/utils/variance_helper.dart` + `test/variance_helper_test.dart`
- `lib/screens/variance_screen.dart`, `lib/screens/inventory_screen.dart`
  (stock-take dialog + action), `lib/providers/inventory_provider.dart`
  (records the variance), `lib/models/inventory_model.dart`, `lib/widgets/custom_drawer.dart`,
  `lib/utils/i18n.dart`

### Validation
- `flutter analyze lib` → 0 errors
- `flutter test` → 264 passing (21 new variance tests)
- `npm --prefix drinks-calculator-backend test` → 8 suites / 104 tests passing
- i18n parity → EN=1072 FR=1072
- No schema change and no ops step: the report is computed from movements the app
  already logs.

---

## Phase 13 — live subscriptions: card / MTN / Orange through Notch Pay ✅ (2026-09-26)

**Where the money actually stands:** the deployed backend reports
`mode: "test"` / `liveReady: false` — the platform Notch Pay account still holds
test keys, so a paid plan can activate without real money moving. The code side is
finished; going live is a Notch Pay dashboard + Render environment action
(`DEPLOY.md` → *Are we taking REAL money yet?*).

### Why card needed its own treatment
Notch Pay's `locked_channel` takes provider slugs (`cm.mtn`, `cm.orange`); card is
not in the published channel list — it appears on their Collect page among the
methods the account is enabled for. So `channel: 'card'` locks to the account's
card channel **when it has one** and otherwise opens the unlocked checkout page.
The app's existing card provider stays as a fallback, and only runs when no
checkout was opened, so a customer is never charged twice.

### What shipped
- `drinks-calculator-backend/utils/paymentChannels.js` (pure, 17 Jest tests):
  `resolveChannel()` (short aliases and raw slugs, junk rejected), `lockCountryFor()`,
  `summarizeChannels()`, `findCardSlug()`, `isCardProvider()`.
- `utils/notchpay.js` → `listChannels()` (`GET /channels`); the route caches it for
  5 minutes. `routes/subscriptions.js`:
  - `notchpay-initiate` resolves the channel server-side, locks the country only
    when it locks a channel, answers **400** for an unknown channel instead of
    forwarding it, and returns `rail` + `channel`;
  - new `GET /subscriptions/notchpay-channels` → `{ known, supported: { card, mtn,
    orange }, cardChannel }`;
  - `/health` now also reports `rails`.
- `lib/utils/payment_channel_helper.dart` (pure, 12 tests) + `subscription_screen.dart`:
  the upgrade sheet is built from `PayRail.card|mtn|orange`, a Mobile Money rail the
  account cannot charge is disabled with the reason, and `known: false` (provider
  unreachable) leaves every rail enabled.
- 4 new EN/FR keys; `DEPLOY.md` documents the dashboard steps, the rail table and
  the verification commands.

### Webhook hardening (security review of the money path)
A review of the payment code found one defect class repeated across four webhook
routes (five verification sites), plus one missing check:

- **Signatures were verified against `JSON.stringify(req.body)`** — the HMAC covers
  the bytes the provider actually sent, and re-serialising changes them
  (whitespace, escaping, number formatting). In live mode this rejects genuine
  webhooks: the subscription would never activate from the webhook, only from the
  app's polling path. Fixed by keeping the raw body in `server.js`
  (`express.json({ verify })`), a small `utils/requestBody.js` (`rawBodyOf`) and
  using it in `/subscriptions/notchpay-webhook`, `/subscriptions/webhook`
  (Flutterwave), `/payment/webhook` and `/payment/notchpay-webhook` (the last one
  checks two secrets, so it had two verification sites).
- **The amount was never checked before activating a subscription** — a leaked
  webhook secret could buy a month for 1 XAF. `utils/paymentGuard.js` now compares
  what was paid with the pending row: overpayment accepted, shortfall refused
  (logged with both amounts), an amount the provider did not repeat accepted.
  `NOTCHPAY_ALLOW_UNDERPAYMENT=true` is the documented escape hatch.
  `activatePendingSubscription` now returns `{ activated, plan, expiresAt, reason }`
  instead of a truthy object, so a refusal can never be mistaken for an activation.
- Replay is a no-op by construction (only a `pending` row activates) and the
  company is resolved from the DB row / session, never from the payload.
- **Test keys can no longer masquerade as live.** The server prints its payment
  mode on startup (`💳 Subscriptions: LIVE keys …` / `🛑 Subscriptions: TEST KEYS —
  real money will NOT be collected`) and the opt-in `NOTCHPAY_REQUIRE_LIVE=true`
  makes `/subscriptions/notchpay-initiate` answer 503 while the keys are test keys.
  Both exist because pasting `pk_test_` keys while expecting real money is an easy,
  silent mistake: the key **prefix** is the only thing that decides the mode.
- **Signing material** is now ignored repository-wide: `android/.gitignore` covers
  `*.jks` / `*.keystore` / `key.properties` only *inside* `android/`, so a keystore
  dropped at the repo root (the usual `flutter build apk` layout) would have been
  committed. The root `.gitignore` now carries `**/*.jks`, `**/*.keystore` and
  `**/key.properties`; verified with `git check-ignore` (`release.jks` ignored,
  `.env.example` still tracked).

### Validation
- `flutter analyze lib` → 0 errors
- `flutter test` → 276 passing (12 new)
- `npm --prefix drinks-calculator-backend test` → 11 suites / 144 tests passing
  (23 new: payment guard 17, request body 6)
- i18n parity → EN=1075 FR=1075
- `node --check` clean on every touched backend file

## Phase 14 - order honesty, legal pages and manuals (2026-10-05, commit 44edf91)

### What shipped
- **Reprint or re-send a past order** (`bd87598`): `receipt_from_order.dart` (+12 tests)
  rebuilds any historical order on the receipt screen, WhatsApp resend included, with
  ten new EN/FR keys.
- **Void an order with a trace** (`aa24533`): `orders.voided_at / voided_by /
  voided_by_name / void_reason`, pure `utils/orderVoid.js` (20 Jest tests),
  `POST /orders/:id/void` and `/restore` (manager-only, reason mandatory), stock put
  back through `inventory_transactions`, and the Z report excluding voids while
  reporting `voidCount` and `voidValue` as their own line.
- **`GET /api/auth/me` now returns `isOwner`** (`44edf91`). Only the login path set
  that flag, so auto-login (cold start) sent a user object without it and the
  owner-only company-logo action answered "not authorized" even to the owner. New
  `utils/companyOwner.js` (`resolveIsOwner`, self-heals a missing `owner_id` claim,
  15 Jest tests) is wired into `controllers/auth.controller.js`, which returns
  `{...userData, isOwner}`.
- **Privacy Policy and Terms rewritten** (`44edf91`): `public/privacy.html`,
  `terms.html` and their French twins. Inline Drink Quick Cal SVG logo, dark-mode
  aware styling, and the clauses a multi-tenant till actually needs -
  controller/processor split (the Shop controls its own customers' data), named
  sub-processors (Supabase, Render, the payment operator), retention plus a 90-day
  deletion window after closure, security measures, user rights, Cameroon Law
  2010/012, the Shop's own legal duties (licence, minors, receipts, taxes), liability
  capped at three months of fees, and Douala as the forum.
- **Manuals** (`44edf91`): `docs/USER_MANUAL.md` follows one service end to end (sell,
  receipt, tab, stock, shift, count, offline, subscription, troubleshooting), and
  `docs/ADMIN_MANUAL.md` is the control manual (role matrix and the protected owner
  row, voids with a trace, discount approvals, variance at cost, cash-up and Z report,
  credit control, price/margin hygiene, subscription and payment reconciliation with
  test versus live mode, security operations, data-protection duties, escalation).
  Both are English with a French summary.

### Validation (2026-10-05)
- `flutter analyze lib` -> 0 errors (503 issues, all pre-existing warnings/infos)
- `flutter test` -> 293 passed
- `npm --prefix drinks-calculator-backend test` -> 13 suites / 175 tests passing
- i18n parity -> EN=1114 FR=1114, no key differences
- `node --check drinks-calculator-backend/server.js` -> clean

### Still open
- **Live money is a human step**: the deployed backend is still in TEST mode
  (`/api/subscriptions/notchpay/health` -> `mode: "test"`); Production Mode plus
  `pk_live_` / `sk_live_` on Render, then `NOTCHPAY_REQUIRE_LIVE=true`.
- Part-payment -> remainder onto the customer's tab: approved, not built.
- `Math.random()` reset/join codes (5 sites) still to move to `crypto.randomInt`;
  rate limiting still covers only the most sensitive endpoints.


### Order corrections hardened (2026-10-10)
- The invoice history's **Void/Restore** was sound, but the calculator's automatic rollbacks used a
  second lane — `PATCH /api/data/orders/:id {is_active:false}` — which set no `voided_at`. The
  Z-report filters sales on `voided_at IS NULL`, so a rolled-back sale kept inflating the shift's
  takings and expected cash, while the app's analytics (which filters `is_active`) excluded it: the
  two numbers disagreed, and the shift cash-up was overstated. A manager also saw such a row drawn as
  "Restore" and, on tapping, ran a void that put back stock the rolled-back sale had never taken.
- Now: **`POST /api/data/orders/:id/cancel`** records who/when/why without moving stock, the Z-report
  counts only `is_active = true` sales and lists untraced cancellations as corrections, a refused
  multi-line sale puts back exactly the lines it had already deducted, and the card's button, dialog
  and toast all follow one tested decision (`lib/utils/order_action_helper.dart`).
  Backend: `tests/order_cancel.test.js` (9 tests) + `tests/order_void.test.js`.

### Re-invoice repaired and manager-gated (2026-10-10)
- "Edit & Re-invoice" could never finish: the cart lines were rebuilt with fabricated ids
  (`import_<ts>_<n>_<name>`), so the stock commit found no inventory row, the sale was refused with
  "not enough stock" while the shelf was full, and a partial return (2 sold, 1 returned) was
  impossible — no unit came back and both stayed counted. Lines are now resolved to the real
  catalogue drink by name (price kept as billed, `utils/invoice_import_helper.dart` + 10 tests), the
  action is manager-gated like a void, and the manager flow returns the right stock
  (10 → sell 2 → 8 → re-invoice 1 → 7 → original voided → 9).
- Still to do as its own feature: a true line-level return (return 1 of 2 in one action, recorded and
  shown on the Z-report) instead of void + re-invoice.

### Returns — "1 of 2 comes back" (2026-10-11)
- New correction lane, next to void and cancel: `POST /api/data/orders/:id/returns` (manager-only)
  with pure `utils/orderReturn.js` (28 Jest tests) and `GET /orders/:id/returns`, which hands the app
  every line with its sold / already-returned / remaining counts.
- The sale stays as billed and still counts; the units go back through the same guarded stock
  primitive a sale uses (`applyStockDelta`) with a movements ledger row (`reason 'return'`,
  `order_id`, `performed_by`, `selling_price_at_sale`). That row is the ceiling for the next return,
  so a unit can never be refunded twice. It is written with `CURRENT_TIMESTAMP` (like a void) so it
  lands in the right shift window, and it is not best-effort for exactly that reason.
- The Z-report gained a **Returns** line (count · units · value) and **Net sales**
  (`sales − returns`), and the refund is taken off `expectedCash`, so a cash-up reconciles instead of
  showing a shortage. Voids and cancellations keep their own line.
- Flutter: a return button on the invoice card (manager-only, only while the sale counts), a
  quantity-stepper dialog drawn from the SERVER's numbers (`utils/order_return_helper.dart` +
  `widgets/return_items_dialog.dart`, 10 tests), a mandatory reason, and a stock refresh from the
  server afterwards instead of local arithmetic.
- Product decision taken (as recommended): returns are a separate line with sales left as invoiced —
  net = sales − returns — matching how voids are handled.
- Gates: backend **24 suites / 371 tests**; Flutter **326 tests**; `flutter analyze lib` 0 errors;
  i18n EN=1193 FR=1193.
- Known gaps: no widget test for the dialog itself (its rules are unit tested); a refund is always
  assumed to be cash out of the drawer — there is no "credit note instead of cash" option yet.


---

## Phase 15 — Returnable containers: who is holding the shop's crates ✅ (2026-10-24)

### Delivered
- **The gap this closes**: the credit ledger answered "who owes me money"; nothing answered
  "who owes me containers". Beer moves in returnable crates and bottles, so a crate sitting in
  a customer's yard is money standing still — and it is the one capability eLeader has for the
  African beer trade (Castel, deployed in Cameroon) that this app did not.
- **A balance is never stored** — `outstanding = out − back − writeoff`, summed from the
  movements exactly like `charged − paid` in the credit ledger, so two staff recording at the
  same moment cannot lose an entry and a corrected ledger stays consistent with its history.
- **The pile can never go below zero**: nobody gives back or writes off more than is actually
  outstanding. The rule is pure and unit tested (`utils/containerLedger.js`,
  `lib/utils/container_ledger_helper.dart`) and the route enforces it with the customer's
  current count — it never trusts the client.
- **Who decides what**: STAFF hand a container out and take one back at the counter (a physical
  fact, like a restock); only a MANAGER writes one off (lost or broken) or changes the container
  list. Containers are GOODS, not credit, so any customer account may hold them — approved or
  not; refusing a blocked customer would only stop staff recording what really happened to the
  shop's crates.
- **Deposits stay informational**: `container_types.deposit_value` is only used to show what the
  outstanding pile is worth. Nothing enters the shift or Z-report maths, so no money test moved.

### Files
- `drinks-calculator-backend/utils/containerLedger.js` + `tests/container_ledger.test.js` (19)
- `drinks-calculator-backend/routes/data.routes.js` — 5 routes (`GET/POST /containers/types`,
  `GET/POST /containers/transactions`, `GET /containers/outstanding`). The aggregate endpoint
  exists on purpose: the movements list is capped at 500 rows, so totals must come from SQL.
- `drinks-calculator-backend/server.js` — boot DDL + RLS + REVOKE for both tables
- `drinks-calculator-backend/sql/rls_containers.sql` + 3 guard tests in `tests/schema_hardening.test.js`
- `lib/models/container_model.dart`, `lib/utils/container_ledger_helper.dart` +
  `test/container_ledger_test.dart` (13)
- `lib/providers/container_provider.dart`, `lib/screens/containers_screen.dart`,
  `lib/config/api_config.dart`, `lib/services/supabase_service.dart`, `lib/main.dart`,
  `lib/widgets/custom_drawer.dart`, `lib/utils/i18n.dart` (`cont*` keys, 31 per language)

### Validation
- `node --check` on the three touched backend files -> clean
- Backend **40 suites / 554 tests** passing (was 39 / 532)
- `flutter test test/container_ledger_test.dart` -> 13 passing
- `flutter analyze lib` -> 0 errors
- i18n parity -> EN=1438 FR=1438, no key differences
- Flutter suite: **418 passing, 1 pre-existing failure** in `test/company_logo_bytes_test.dart`
  (line 74 asserts `status.notchPayConfigured`, a getter removed by the CamerPay migration —
  unrelated to this phase, still open)

### Still open
- No auto-derivation from a sale: a crate sale does not create container lines (a shortcut
  button on the invoice is the planned follow-up).
- No supplier-side mirror ("containers the shop owes the distributor") — that belongs with the
  supplier / purchase-order feature.
- No deposit money flow: charging a deposit would touch the credit ledger and the Z-report, and
  is deliberately not in this phase.

---

## Phase 16 — Buying stock: suppliers, purchase orders and receiving 🟡 (backend shipped 2026-10-24)

### Why
The forecast already recommends what to reorder, but nothing could turn that into an order and
nothing remembered what a supplier charges — the project's own notes said it plainly:
*"supplier prices are not stored yet"*. This is the largest remaining eLeader gap and the one that
unlocks wholesalers (their DMS does exactly this for distributors).

### Delivered (backend)
- **Schema** — `suppliers`, `purchase_orders`, `purchase_order_lines`, created at boot with RLS +
  `REVOKE` on all three (`sql/rls_purchasing.sql` mirrors it for ops), plus 3 guard tests in
  `tests/schema_hardening.test.js`.
- **Routes** — `GET/POST /suppliers`, `GET/POST /purchase-orders`, `PATCH /purchase-orders/:id`
  (send / cancel), `POST /purchase-orders/:id/receive`.
- **Who decides what** — a manager commits the shop's money (create, send, cancel); **any** staff
  member may receive a delivery, because that is a physical fact at the door like a restock. The
  rules are pure and unit tested (`utils/purchasing.js`, 15 tests).
- **Receiving reuses the guarded path** — `applyStockDelta`, so it can never drive a shelf negative
  and it writes the movement with `reason: 'purchase_order'` and the PO reference as `order_id`.
  One refusal stops the whole delivery and leaves the order `sent`, so it can be received again once
  the shelf is right — instead of half of it landing and half vanishing.
- **Identity** — the reference is generated from the row id (`PO-000123`), so two orders can never
  share one, and the supplier is validated against the company rather than trusted from the body.

### Still to build (app side)
- `ApiConfig` endpoints + a `PurchasingProvider`. ✅ shipped `97b1f88`
- A suppliers + purchase-orders screen (draft → send → receive). ✅ shipped `97b1f88`
- **Create an order from the forecast** — the whole point of the loop. ✅ shipped `a0220d1`
- EN/FR keys. ✅ shipped `97b1f88` (`pur*`, 35 per language) + `purFromForecast`/`purForecast*` in `a0220d1`

### Validation
- `node --check` on the three touched files -> clean
- Backend **43 suites / 592 tests** passing (was 42 / 574)
- App side: `flutter analyze lib` 0 errors, i18n EN=1476 FR=1476, Flutter **426 tests**

---

## Phase 17 — Notch Pay removed: CamerPay is the only payment rail ✅ (2026-10-28)

### Why
Phase 13 wired subscriptions through Notch Pay; the CamerPay migration replaced it, but the legacy
rail was kept on purpose — `campay_enabled` defaults to false and no company had connected its own
account, so deleting the old path would have stopped every shop from taking electronic money. The
till was moved to refuse the legacy path first (`campay_not_connected`), and once that shipped the
dead code could go.

### Deleted
- `utils/notchpay.js`, `utils/paymentChannels.js` (and their two Jest suites).
- Six `/subscriptions/notchpay-*` routes: initiate, status, webhook, return, health, channels.
- `POST /payment/notchpay-webhook`, `GET /payment/notchpay-return`, the Notch Pay Sync poll in
  `GET /payment/status/:id`, and the unreachable legacy body of `POST /payment/initiate`.
- The four `notchpay_*` columns created at boot, and `notchpay_sync_id` from
  `GET/PATCH /payment/company-settings` (`sql/drop_notchpay_columns.sql` drops them in the database).

### Changed
- `GET /payment/health` reports CamerPay readiness (`credentials.isConnected`) instead of
  "platform Notch Pay keys + a company sync id".
- The app's `notchpayInitiate` / `notchpayStatus` are now `campayInitiate` / `campayStatus` (they
  already called CamerPay endpoints); `PayChannelAvailability` is gone — CamerPay publishes no
  per-rail list, so all three rails are offered and its own page refuses with a reason.
- `.env.example` documents CamerPay and `PAYMENTS_*`; `scripts/check_payments.js` checks
  `/subscriptions/campay/health`.

### Deliberately kept
- The `NOTCHPAY_REQUIRE_LIVE` / `NOTCHPAY_ALLOW_UNDERPAYMENT` env aliases in
  `utils/paymentGuard.js`: a deployment that set them would otherwise lose the live-money guard
  silently. `PAYMENTS_*` is the documented name.

### Validation
- `node --check` clean on every touched backend file
- Backend **44 suites / 584 tests** (was 46 / 606 — the NotchPay-only suites are gone)
- `flutter analyze lib`: 0 errors (537-issue baseline); Flutter **428 tests, 0 failures**
- i18n **EN=1480 FR=1480**
- Human step left: run `sql/drop_notchpay_columns.sql` in the Supabase SQL editor, and set
  `PAYMENTS_REQUIRE_LIVE=true` on Render.

---

## Admin — per-company CamerPay readiness ✅ (2026-10-28)

### Why
B2C collection is per company: each bar connects its OWN CamerPay account, the till charges through
it, and the fee is the bar's cost (never booked as revenue). What was missing was a way for the
platform owner to answer "which of my companies can actually collect?" — and 0 of 6 are connected,
so every till refuses electronic payment with `campay_not_connected` and the sale must be cash.

### Delivered
- `utils/companyReadiness.js` — one admin row per company (booleans + blockers + a single
  `nextStep`), built on `credentials.healthFor` so the Settings card and this list cannot disagree.
  The order puts a server-side blocker (`set_vault_key`) before a company-side one, so nobody is
  asked to connect an account the server cannot store.
- `GET /api/admin/campay-readiness` — platform-admin gated, secret-free: it never reads
  `campay_webhook_token` and returns no token, masked token or webhook URL (that URL's path is the
  company's opaque webhook token).
- `scripts/campay_readiness.js` (`npm run campay:readiness`) — password from the environment, exit 1
  while any company is blocked, so it doubles as a post-deploy ops check.
- `.env.example` — removed the duplicate `ADMIN_PASSWORD` and the false "falls back to admin123"
  claim (the override is disabled below 12 characters).

### Still human
Each company creates its own CamerPay token and completes its own KYC, then pastes the token and
webhook secret in Settings → Business Payment Settings. **`PAYMENT_CREDENTIALS_KEY` is already set
on Render (confirmed by the owner, 2026-10-28)**, so nothing platform-side blocks a company from
connecting — and the ops script now prints that key's state on its first line, so the claim stays
checkable instead of assumed.

### Validation
- Backend **45 suites / 595 tests** (+1 suite / +11 tests); `node --check` clean on all four files
- Script behaviour verified: missing password → clear message + exit 1; wrong password → HTTP 404
  (the route is not deployed yet)

---

## Security — the plaintext payment credentials are gone ✅ (2026-10-29)

### Why
`companies` still carried 6/6 non-null plaintext `mtn_api_key` / `mtn_secret_key` / `orange_*` rows for
a rail that no longer exists, and the drop script could not run because the app wrote those keys and
the backend read them. That was the last known liability in the payment area — and the repo is public,
so the schema was documented for anyone.

### Delivered
- **Every read and write removed:** `GET/PATCH /payment/company-settings` handle the four switches
  only, the legacy MTN auto-verification in `GET /payment/status/:id` is gone, `/payment/health` no
  longer reports a per-rail sandbox mode, `/api/data/company` and the public company profile stop
  selecting the six columns, and `/company/payment-credentials` is deleted with its columns.
- **The app plumbing is gone:** the credential fields, controllers, prefs cache and load/save maps in
  `storage_settings_screen.dart` + `payment_helper.dart`, plus 13 dead `st_*` i18n keys (EN and FR).
  The toggles stay; the purge of old pref values stays, because an upgraded device may still hold a
  plaintext provider key.
- **`COMPANY_SECRET_COLUMNS` now strips the CamerPay secrets**, so the route that returns `SELECT *`
  for a company can no longer hand out ciphertext or the webhook path token.
- **Two legacy endpoints deleted, one a security fix:** `POST /payment/orange-webhook` was
  unauthenticated and could mark a transaction completed from the request body alone.
- **`isMaskedOrEmpty` now recognises `****`**, the mask this API itself emits, so a round-tripped
  mask can never be stored as a token.
- `sql/drop_dead_payment_columns.sql` is ready — run it only **after** this deploys.

### Validation
- Backend **46 suites / 603 tests** (+1 suite / +7 tests); `node --check` clean
- `flutter analyze lib` 0 errors (537-issue baseline); Flutter **428 tests**; i18n **EN=1466 FR=1466**
- `tests/payment_credentials_removed.test.js` fails if any dropped column name reappears in the
  backend, or if the app starts sending the camelCase fields again

---

## Security — a CamerPay credential change is re-authenticated, audited and reported ✅ (2026-10-29)

### Why
`PATCH /payment/campay-settings` was the one money-moving settings action with no audit row and no second
check. Replacing a company's CamerPay token silently redirects where that company's money lands, so a
session left open on an unlocked till was enough to do it.

### Delivered
- **Re-authentication for the token.** Storing or replacing it requires the actor's own password,
  verified with bcrypt exactly like login (including the legacy plaintext fallback that upgrades the
  hash), bounded by a small auth queue and rate-limited to 5 tries / 15 minutes per user. Rotating the
  webhook token or flipping the switch needs nothing extra — those move no money.
- **Audit trail.** Every change writes `company.payment_credential` to `audit_log` with the actor and a
  description (booleans only, never the values).
- **Owner notice.** A token or webhook-secret change emails the company owner with who did it, when, and
  what to do if it was not them. Best effort — the audit row is the durable record.
- **App.** Both save paths prompt for the password when a token is typed; cancelling sends nothing, and
  the three refusal codes are shown as translated sentences (EN + FR).

### Validation
- Backend **47 suites / 615 tests** (+1 suite / +12 tests); `node --check` clean
- `flutter analyze lib` 0 errors (537-issue baseline); Flutter **428 tests**; i18n **EN=1473 FR=1473**
- `tests/payment_credential_change.test.js` pins the three controls, the bcrypt-only rule and the
  machine codes the app translates

---

## App — drawer navigation: truthful highlight, grouping and search ✅ (2026-10-29)

### Why
The drawer was a 20-entry list. Its highlight was hardcoded to Dashboard; `menuManagement` and
`menuSupport` existed but were used zero times (the grouping was started and never finished); there was
no search; and one file compared roles two ways (`role == 'manager'` and `user.role == 'Manager'`).

### Delivered
- **The highlight is derived from the screen** the drawer is open on, so it cannot claim you are
  somewhere you are not. Tapping the entry you are already on closes the drawer instead of stacking a
  second copy of the same screen.
- **Grouping** in `utils/drawer_navigation.dart` (pure, unit tested): Daily → Reports → Setup → Manager
  → Admin → Support, daily work first. The two dead keys became the Reports and Support headers, and a
  section with nothing visible is not rendered at all.
- **Search** at the top of the menu: filters by translated label, case- and accent-insensitive, with a
  "nothing matches" line.
- **One role rule**: `StaffPermissions` normalises and answers every role question; `'Owner'` counts as a
  manager, which is how the backend already treats it.
- Two hardcoded English headers (`MANAGEMENT`, `SUPPORT`) the i18n sweeps had missed are translated now.
- The drawer shell is 902 lines (was 1301); the menu is `widgets/drawer_menu.dart`.

### Known limitation (not done)
The drawer is mounted only on the calculator, so moving between two other screens always goes back
through it. Mounting it on the top-level screens — and a `NavigationRail` for tablet widths — is the
next step.

### Validation
- `flutter analyze lib` **535 issues** (was 537), 0 errors; Flutter **443 tests** (15 new: grouping,
  search, role helpers, and a widget test proving the highlight follows the screen)
- i18n **EN=1477 FR=1477**

---

## App — design tokens, piloted on the drawer ✅ (2026-10-29)

### Why
27 gradients, 33 one-off box shadows and 194 hand-picked `withValues(alpha:)` values meant the drawer, the
cards, the dialogs and the till each expressed "a surface" slightly differently. The defect was
inconsistency, not the style.

### Decision (recorded so it is not relitigated)
**Material 3 + restrained soft depth. Not glassmorphism, not neumorphism, not claymorphism.** This is a
till used in daylight on low-end Android (`minSdk = flutter.minSdkVersion`) with money figures a cashier
must read unambiguously: `BackdropFilter` (0 uses today) re-blurs every frame over a scrolling list,
neumorphism encodes state with shadow alone and loses contrast, claymorphism fights a data-dense UI.
Glass remains an option for 2–3 *static* surfaces (drawer header, a floating bar, dialogs) — never a list.

### Delivered
- `lib/theme/app_theme.dart`: radius (8/12/16/pill), spacing, alpha steps, two theme-aware shadow levels,
  the single `AppBrand` gradient + on-surface colours, `AppText`, and `AppRoleBadge` (pure + tested).
- The drawer is the pilot: one brand surface in the header, tokens for the role chip and sync pill, and a
  selected entry using M3's `secondaryContainer` / `onSecondaryContainer` instead of a 10 % primary tint
  that vanished in dark mode. Selection stays signalled three ways (bold + accent bar + tinted panel).
- Both themes in `main.dart` now derive `secondaryContainer` from the brand colour — previously
  `ColorScheme.light/dark` set only `primary`/`secondary`, so that role was Flutter's default lavender.

### Validation
- `flutter analyze lib` **535 issues**, 0 errors (unchanged); Flutter **455 tests** (+12)
- `test/app_theme_test.dart` pins the scales, the gradient, the badge colours, and guards the drawer
  against drifting back to hand-picked values; the drawer test file gained a dark-mode case
- i18n unchanged (no new keys)


## 2026-10-31 — The drawer reaches every top-level screen (and keeps the back arrow)
The drawer was mounted in exactly ONE place (`calculator_screen.dart`), so the other destinations formed a
hub: getting from Inventory to Shift meant going back to the till first. Reported on 2026-10-29, now fixed.
- **`lib/widgets/drawer_menu_button.dart`** (new): the menu button for a screen that is not the till. It is a
  widget rather than an inline `IconButton` because the obvious version
  (`AppBar(actions: [IconButton(onPressed: () => Scaffold.of(context).openDrawer())])`) throws *"No Scaffold
  widget found"*: that `context` belongs to the enclosing build method, which sits **above** the Scaffold
  (`app_bar.dart`). The widget's own context is below it, so the trap cannot be reintroduced by accident.
- **The subtlety that decided the design**: a Scaffold's `drawer` does **not** coexist with the implied back
  arrow. `AppBar` resolves the leading slot as `if (hasDrawer) leading = DrawerButton()` — *before* the
  `parentRoute.impliesAppBarDismissal` branch — so adding a drawer silently turns the back arrow into a
  hamburger. Pinning an **explicit** `leading: BackButton()` wins (`Widget? leading = widget.leading;` is read
  first), so every screen keeps back on the left and opens the drawer from a menu button in `actions`.
  Dragging from the left edge still opens the drawer too.
- **Applied to 17 screens**: inventory, drinks, shift, customers (ledger), containers, purchasing, analytics
  (dashboard), forecast, variance, staff (manager panel), approvals, settings, profile, subscription, AI
  assistant, admin panel and report-a-problem. The till is unchanged: it owns its drawer and its three
  hamburgers, and its `currentScreen` already defaults to `DrawerScreen.dashboard`.
- **Deliberately not mounted**: the barcode scanner (`barcode_scan_page.dart` is a focused camera task), and
  the entries that are not screens at all — `invoices`, `about` and `help` are callbacks the till handles.
  Sub-screens that are not drawer destinations (inventory report, admin support reports, notifications) are
  left alone, so the menu never offers a way to somewhere the user did not come from.
- **Subscription is conditional on purpose**: opened from the drawer it gets the drawer and a pinned back
  arrow; opened as a paywall gate (`widget.gate`) it stays a modal detour — no back arrow, no drawer.
- Guards: `test/drawer_menu_button_test.dart` (new) pumps a pushed screen and asserts **both** invariants — the
  back arrow survives *and* the button opens the drawer. It is what caught the leading-slot mistake: the first
  run failed with `Found 0 widgets with type "BackButton"`.
- Gates: `flutter analyze lib` **535 issues**, no `error -` (unchanged); Flutter **456 tests** (+1);
  i18n unchanged (no new keys, reuses `menu`). Backend untouched.

## 2026-10-31 — Reports: the margin is real now, and the two "general" prices exist
The report screen priced a historical sale with **today's** numbers: revenue from `drink.price` (the
current catalogue) and cost from `item.purchasePrice` (the current stock row). Three consequences, all of
them money the owner reads as fact:
- editing a price this afternoon silently rewrote last month's report;
- a drink that had left the catalogue (or had no stock row) fell back to a zero object, so the sale
  contributed 0 revenue **and** 0 cost — which the margin reported as **100 %**;
- the ledger already stored the correct basis (`sellingPriceAtSale` / `purchasePriceAtSale` on every sale
  movement) and the screen ignored it.
- **`lib/utils/report_profit_helper.dart`** (new, pure): `ProfitLine` → `ProfitSummary`. Prices from the
  ledger first, the catalogue only for legacy movements, and never invents a cost of 0 (a cost of 0 is read
  as "not on record"). It counts `unitsWithoutCost` / `unitsUnvalued` so the screen can caveat a figure
  instead of flattering it.
- **The Profit tab now shows** revenue, cost, profit, margin **plus the two "general" prices asked for** —
  average selling price and average purchase price per unit sold in the period — with an amber caveat when
  some units had no cost on record or could not be valued at all. Keys: `rpt_avgSellingPrice`,
  `rpt_avgPurchasePrice`, `rpt_perUnitSold`, `rpt_caveatNoCost`, `rpt_caveatUnvalued` (EN+FR).
- **Two bugs found on the way**: `test/screens_layout_test.dart` had never actually laid this screen out —
  the harness injects a free plan, so the screen rendered its upgrade view and neither tab was ever
  measured. Fixing that immediately exposed a real **100 px RenderFlex overflow** in the date-range card (an
  unbounded `Column` inside a `Row`) on a phone; it is an `Expanded` now and wraps.
- Gates: Flutter **468 tests** (+12), `flutter analyze lib` **534 issues** / 0 errors (one fewer than before
  — the dead calculation code is gone), i18n **EN=1482 FR=1482**. Backend untouched.
- **Still open**: the downloadable report (`ExportHelper.exportInventoryReport`) carries no money figures at
  all — the totals, margin and averages exist only on screen.

## 2026-10-31 — The money now leaves the app with the report
Follow-on to the entry above: the Profit tab had the figures, the **exported file** did not.
`ExportHelper.exportInventoryReport` wrote stock counts, categories, expiry and movements, so the totals, the
margin and the two averages could never reach an accountant.
- **One definition, three formats**: `InventoryReportFiles.profitRows(profit, t)` builds the label/value rows
  once, and both the Excel sheet (`Profit`, next to `Summary`) and the CSV block consume it — so the two
  formats cannot drift apart. A test asserts that function directly, which is the honest way to cover the
  sheet: the `excel` package cannot re-parse a workbook containing the empty spacer rows this builder writes.
- **Numbers stay numbers** in Excel and CSV (two decimals) so a spreadsheet can sum the column; the PDF is
  the presentation one and takes an optional `currencySymbol` from the caller.
- **The caveats travel with the figures**: units with no cost on record, and units that could not be valued,
  are printed under the money block in the PDF and as extra rows in Excel/CSV. A file that leaves the
  building must not read better than the screen it came from.
- **The screen passes its own summary in** (`profit: _profitSummary()`), so file and screen are one
  calculation rather than two that can disagree.
- The export dialog gained a **Profit & margins** checkbox, appended last so the existing checkbox order —
  and `optionsFromSelection` — stays stable for every caller.
- New keys: `exp_profitSection`, `exp_unitsSold` (EN+FR).
- Gates: Flutter **476 tests** (+8), `flutter analyze lib` **534 issues** / 0 errors,
  i18n **EN=1484 FR=1484**. Backend untouched.

## 2026-10-31 — The chosen style, applied app-wide (soft depth + one glass surface)
The 2026-10-29 entry *decided* the style — **Material 3 with restrained soft depth; no glassmorphism,
neumorphism or claymorphism** — but only piloted it on the drawer: `app_theme.dart` was imported by three
files, and every other screen still hand-picked its own radii, alphas and shadows. This puts the decision
where it actually takes effect.
- **The leverage point is the theme, not 200 widgets.** `_buildLightTheme` / `_buildDarkTheme` in `main.dart`
  now take their radii and elevations from the tokens (`AppRadius.mediumAll` for buttons and inputs,
  `AppRadius.largeAll` for cards, `AppElevation.raised` / `floating`), so every screen inherits one surface
  language instead of re-guessing it. The two hand-picked theme radii (12 and 16) are gone, and a test fails
  if either comes back.
- **The surfaces that had no rule were given one**: `dialogTheme`, `bottomSheetTheme`, `snackBarTheme`, plus
  `filledButtonTheme` and `textButtonTheme`. Before this, every dialog and sheet took whatever shape the
  screen that opened it felt like — exactly the inconsistency the token file was written to stop.
  `AppElevation` is new (flat 0 / soft 2 / raised 4 / floating 8), so "what floats" is a name, not a number.
- **One glass surface, deliberately.** `AppGlass` (blur 12, a tint, a hairline edge) is applied to the **lock
  overlay** — the one surface whose backdrop cannot move (it covers a frozen app) and whose brand gradient is
  already translucent, so the blur reads through it. It is applied in the overlay rather than in the lock
  screen's body, because the overlay is what covers the app: that is what puts the blur on the screen behind.
  **Why not everywhere**: `BackdropFilter` re-blurs its region every frame, so glass behind a scrolling list
  spends a low-end phone's frame budget while a cashier scrolls for a bottle. Two tests encode the rule — no
  file under `lib/screens/` may mention `AppGlass`, and it may be applied exactly once.
- Gates: Flutter **483 tests** (+7), `flutter analyze lib` **534 issues** / 0 errors. i18n and backend
  untouched.
- **Still open**: the per-screen cleanup — 36 hand-picked `BoxShadow`, 27 `LinearGradient` and ~197
  `withValues(alpha:)` calls remain in screens that predate the tokens.

## 2026-10-31 — Per-screen cleanup: 533 hand-picked values moved onto the tokens
The token file's own header complained about "27 gradients, 33 one-off box shadows and 194 hand-picked
`withValues(alpha:)` values". This is the sweep that fixes the mechanical part of that — and the measurement
that says where the line is.
- **Radii first, because they are decidable.** 8 / 12 / 16 were already the token values (204 sites, zero pixel
  change) and **20 was used 53 times — more than `small`** — so `AppRadius.xlarge` was added rather than forcing
  53 sites onto a different corner: the scale was wrong, the code was right.
- **`AppRadius`'s getters became `const` fields.** `BorderRadius.all` is a const constructor, so a token can
  live inside a `const` widget. Without that, every `const` widget holding a radius would have had to lose its
  `const` — which is precisely why the migration could be scripted at all.
- **Then the overlay tints**: 0.1 / 0.2 / 0.06 → `AppAlpha.subtle` / `medium` / `faint` (82 sites, no change).
- **533 replacements across 43 files in one pass**: 339 exact (pixels do not move) and 194 snapped to the
  nearest step (10→12 ×73, 0.3→0.32 ×26, 0.15→0.10 ×16, plus a short tail). Every snapped value was reported by
  count, never applied silently.
- **Two categories were deliberately NOT swept** — the interesting part:
  - **Alphas above 0.32 stay literal** (40 sites). Those are compositional opacity (gradient stops, scrims),
    not overlay tints: `AppAlpha` describes how much a tint shows through, and mapping `0.7` onto a tint step
    would have wrecked the lock screen's translucent gradient — the very thing the new glass reads through.
  - **Box shadows and gradients stay literal** (36 and 27). Measured: 17 distinct blur values with no dominant
    pattern, 4 shadows built from variables, and one **orange glow** that is a semantic warning, not depth.
    Snapping those to `AppShadow.soft` / `raised` would redesign every raised surface in the app, and no test
    can see that — it needs eyes on a screen. Recorded instead of guessed at.
- **Guards added** (`test/app_theme_test.dart`, now 20 tests): nothing under `lib/` may re-introduce
  `BorderRadius.circular(8|12|16|20)` (excluding the PDF package's own `pw.BorderRadius`) or
  `withValues(alpha: 0.06|0.1|0.2)`, so the migration cannot quietly undo itself.
- **One scripted-pass bug, caught by the compiler**: the literal `BorderRadius.circular(N)` rule also matched
  **`pw.BorderRadius.circular(N)`** — the `pdf` package's own class — in the invoice and report builders,
  leaving a dangling `pw.` prefix on 7 sites. Restored to their PDF radii, and the import the pass had added to
  those two files was removed again.
- Gates: Flutter **485 tests**, `flutter analyze lib` **534 issues** / 0 errors (unchanged). Backend untouched.

## 2026-11-01 — Recipe / pour cost (Phase 18): what a MADE drink costs
The gap every serious competitor closes and this app did not. `drinks.purchase_price` prices a drink bought
and resold whole, but a drink **assembled at the counter** (a cocktail, a bottle served by the glass) had no
cost at all — so the margin on the best-selling item in the shop was invisible.
- **New table `drink_recipes`** (company-scoped, RLS + REVOKE at boot *and* in `sql/rls_recipes.sql`), one row
  per ingredient line: `quantity NUMERIC(12,3)` (0.05 of a litre is a normal pour), `unit`, an optional cost
  override and an optional pack size. An ingredient is either a stocked drink or a free-text input (ice, a
  garnish) — the catalogue is not a prerequisite for costing a garnish.
- **The cost is COMPUTED, never stored** (`utils/recipeCosting.js`): every read prices the recipe from the
  ingredients' current purchase prices, so one supplier price change moves every margin at once and no row can
  ever disagree with its own history. Nested recipes work (a pre-mix), with a cycle guard (A→B→A) and a depth
  cap — both unit tested.
- **It never invents a 0 cost.** A line with no price on record is left OUT and COUNTED (`complete: false`) and
  the screen shows the caveat. This is deliberately the same discipline as the Reports profit fix: a "free"
  ingredient reads as a 100 % margin.
- **Routes** (manager-only via `canManageRecipes`, `requirePlan(['pro'])`): `GET /recipes/costing`,
  `GET|POST|DELETE /recipes/:drinkId`, `GET /drinks/:id/cost`. A recipe is replaced in ONE statement (a
  data-modifying CTE), so a failure leaves the old recipe intact instead of a drink holding half its
  ingredients. `/recipes/costing` is declared before `/recipes/:drinkId` (a test pins the order).
- **Receiving now remembers what the delivery cost** (`UPDATE drinks SET purchase_price`). Until now a delivery
  moved stock but never refreshed the cost, so the Reports "average purchase price" card and every margin went
  stale silently. A line priced at 0 is left alone — that is "no price given", not a free delivery.
- **App**: `utils/recipe_cost_helper.dart` (pure, 13 tests) + `models/recipe_model.dart` +
  `providers/recipe_provider.dart` + `widgets/recipe_editor_dialog.dart`, reached from the drink form, which
  shows cost / pour cost / the price that would hold the target **live while typing**. No offline cache on
  purpose: a margin from last week shown as today's is the exact confident-wrong-number this feature exists to
  prevent.
- **PHASE A: a recipe does not move stock.** Selling a cocktail still deducts the cocktail, so the variance
  report and the Z-report are untouched. Ingredient deduction is a deliberate, opt-in Phase B, and a test
  asserts no recipe route touches `inventory`.
- Gates: backend **643 tests** / 48 suites (+22), Flutter **498 tests** (+13), `flutter analyze lib` **489
  issues / 0 errors**, i18n **EN=1515 FR=1515**.
- **Open**: the pour cost report screen (`GET /recipes/costing` is served and parsed, no screen renders it
  yet); Phase B ingredient deduction; per-company target pour cost (currently the 20 % default).

The last open item was "36 hand-picked box shadows and 27 gradients". Measured properly, it is **not** a
migration task, and this entry records why rather than pretending otherwise.
- **The till has no shadows at all** and exactly one gradient — its background. That one *was* a surface, so it
  now uses the `AppBrand.surface(primaryColor)` token, which is what makes the till and the drawer header
  visibly the same surface. It used to fade the brand to 70 % opacity (letting the scaffold bleed through); the
  token darkens it instead. **Dark mode keeps its neutral grey on purpose** — a brand-coloured till is a design
  decision, not a token swap.
- **Most "shadows" are not depth, they are colour.** Of the 19 `BoxShadow(` sites, the ones that carry meaning
  are semantic glows: the sync indicator's status colour, the AI button's purple pulse, the auth screen's
  orange warning, the subscription screen's brand glow. Mapping those onto `AppShadow.soft` / `raised`
  (neutral black) would **delete the meaning** — a green "synced" glow would become grey depth.
- **The depth shadows that remain are crisper than either token level.** They run blur 4–10 with offset (0,1)–
  (0,2); `soft` is blur 16 / offset (0,4) and `raised` is blur 28 / offset (0,8). Forcing them onto the tokens
  would make every card in the app noticeably fuzzier — a redesign, not a migration, and one no test can see.
  There is also no dominant value to promote to a token the way `AppRadius.xlarge` promoted 20.
- **The gradients are nearly all semantic too**: the AI button's green→purple, status colours, the lock
  screen's translucent brand gradient (which the glass reads through — tokenising it would break the glass).
  The till's background was the one that was a surface rather than a signal.
- **What the pass did find and fix**: **53 deprecated `Color.withOpacity` calls** (missed by the earlier alpha
  sweep because it only matched `withValues`). Renamed to `withValues(alpha:)` — which is also a precision fix
  — and **46 of them moved onto the `AppAlpha` steps**. That is a measurable win: `flutter analyze lib` dropped
  from **534 to 481 issues**, with the 53 deprecation infos gone.
- Gates: Flutter **485 tests**, `flutter analyze lib` **481 issues** / 0 errors. Backend untouched.
- **The honest finish line**: every category that could be decided mechanically is on the tokens (radii, overlay
  tints, deprecated API). What is left is 11 intentional subtle depth shadows and ~28 semantic gradients, and
  mapping those would make the app worse, not more consistent.

---

## 2026-11-01 — Recipe follow-ons: the pour cost report, Phase B, a per-shop target ✅

**Value:** High · **Risk:** Medium (Phase B moves stock) · **Hardware:** none

Three follow-ons from Phase 18 — all manager-only and Pro, the same two gates the backend enforces.

### 1. The pour cost report screen
- `GET /recipes/costing` was served and parsed into `RecipeProvider.report` with **nothing rendering it**. The screen answers the question the whole feature exists for: **which drink is losing me money**.
- Header: a shop-wide pour cost **weighted by units sold** — 45 % on a drink nobody orders is not the same problem as 45 % on the best seller, and a plain average would say it was. Plus the units and the margin the window earned, and the target every margin is read against.
- Every drink worst-first (the server's ranking): cost, margin, units sold, suggested price, a pour-cost chip coloured against the shop's own target, and **the caveat instead of a flattering margin** when a price is missing. Tapping a drink opens its recipe.
- 7/30/90-day window — the same choice the shrinkage report offers, so the two read alike. **No offline cache**: a margin from last week shown as today's is exactly the wrong number this feature exists to prevent.
- Drawer entry in the **Reports** group, gated by `canAccess('recipes')` — the app's mirror of `requirePlan(['pro'])`.
- `RecipeCostHelper.totals` (+ `PourCostSample` / `PourCostTotals`) is pure and tested; the layout harness now seeds a report through the provider (`RecipeProvider.seedReport`, a `recipes:` hook in `pumpScreen`) so the **cards** are laid out on phone and tablet instead of only the plan gate.

### 2. Phase B — a sale takes the recipe's ingredients with it
- Selling a made drink now moves the **whole units** its recipe calls for, through the same atomic primitive a sale uses, so two tills cannot both take the last crate.
- **Whole units only, deliberately**: `inventory.quantity` is an integer everywhere in the app, so a fractional pour (0.05 of a bottle) cannot be written into that ledger — it would fail or truncate to zero. Such a line comes back in `notTracked` and is **reported, never dropped silently**. It is also the business: a whole-unit retailer.
- **Best-effort**: the sale is already saved, so a missing recipe, an unstocked ingredient or not-enough-on-the-shelf is reported and never fails a completed sale.
- The movement is logged with reason `'recipe'`, which the shrinkage report now classifies as **neither a sale nor a loss** (`VarianceHelper.consumptionReasons`): the ingredient was never sold at its own price, so counting it as a sale would inflate the sold value the loss rate is measured against, and counting it as a loss would call a sold cocktail missing stock.
- New pure module `utils/recipeStock.js` (**9 Jest tests**) + `moveIngredientsForSale` in `POST /inventory/sell`.

### 3. Per-company target pour cost
- The "charge X" hint and the margin colours were read against a hard-coded 20 %. It is now a company setting: `companies.target_pour_cost`, set with `PATCH /recipes/target` (manager-only, Pro) and read per request so a change follows at once.
- **NULL means the built-in default**, so clearing it is a real choice. A value the server cannot use is **refused with 400**, never silently replaced by the default — a setting that looks saved but is not is worse than an error — and the app applies the same rule (`RecipeCostHelper.normaliseTargetPourCost`) before sending.
- The target line on the report is tappable to change it.

### Validation
- Backend **49 suites / 655 tests**, Flutter **522 tests**, `flutter analyze lib` **0 errors**, i18n **EN=1524 FR=1524**.

### Still open (named, not pretended)
- Phase B is whole-unit only by decision. A shop that sells by the pour would need a fractional ledger (a remainder column plus pour accumulation) — not built.
- A shop stocking BOTH a bundle and its parts will see both move (the recipe adds to the sale's own deduction). That is a catalogue setup question, flagged rather than guessed.
- The `companies.target_pour_cost` column is added by the boot `ALTER`, so it exists after the next **manual** deploy; until then the read falls back to the built-in 20 % and saving is best-effort.


## 2026-11-10 — "There is a newer build": the app tells the shop, not the other way round ✅

The app is handed out as an APK, so no app store announces a release. Until now a shop only learned about a
newer build if a human remembered to say so.

### 1. `GET /api/app/release` — one public question, driven by the environment
- Answers what the newest build is, from `APP_LATEST_VERSION`, `APP_LATEST_BUILD`, `APP_APK_URL`, `APP_RELEASE_NOTES` and `APP_UPDATE_MANDATORY` — so the file can move (a release page, a CDN, Drive) without touching the app.
- **Nothing configured ⇒ `known: false` ⇒ the app stays silent.** An announcement channel that cries wolf is one a shop learns to dismiss — including the day it matters.
- Public on purpose: it is the app's own "am I old?" question and it carries nothing about any company. The rule is pure (`utils/appRelease.js`, **12 Jest tests**).

### 2. The notice itself
- Checked a few seconds after startup, once per app run, and it never competes with the first frame.
- The comparison is pure and testable without a widget (`utils/app_update_helper.dart`): a dotted version compared **numerically** — string-compared, `1.10.0` would look older than `1.9.0` — with the **build number as the tie-break**, which is what makes a rebuild of the same version news.
- A **dialog**, not a banner: no AppBar, no layout shift on a screen sized for a till.
- **"Later" always works.** A mandatory release only re-shows; it never traps a shop mid-service behind a dead button, and it cannot brick a till that has no connection to download with.
- Mounted as `home:` **inside** the Navigator, so the global lock overlay still covers it — a locked till must not show a dialog over the lock screen.
- Both languages. A failed check is silent: a shop with no signal sees no error, and the next run asks again.
- **The version it compares against is `AppConstants.appVersion` / `appBuild`** — the app's single declared source of truth, pinned to `pubspec.yaml` by `test/app_info_test.dart`, which now guards the build number too. This feature's first draft carried its own copy of the version, and that guard failed the suite — which is exactly what it is for.

### Validation
- Backend **50 suites / 666 tests**, Flutter **539 tests**, `flutter analyze lib` **0 errors**, i18n **EN=1529 FR=1529**.

### Still open (named, not pretended)
- The route exists in production only after the next **manual** Render deploy, and a push alone does not deploy — `GET /health`'s `RELEASE` marker is the proof (a 17-minute poll once produced a wrong answer here: one deploy took 21m46s).
- The APK is not signed with a release key yet (`key.properties` + `build.gradle.kts`) and there is no download page (APK + SHA-256 + install steps) under `drinks-calculator-backend/public/`. Both should land before `APP_APK_URL` points anywhere honestly.


## 2026-11-10 — A signed APK and a download page: the update notice now points somewhere honest ✅

The app tells a shop a newer build exists and opens a link for it. Until now that link could not
have worked as an *update*, because every published build was signed with the **debug** key
(`build.gradle.kts` fell back to it), and Android only accepts an update signed by the same key as
the installed app. So the notice could only ever have produced an "app not installed" error.

### 1. Signing, with the debug fallback closed
- `android/app/build.gradle.kts` reads a real `signingConfigs.release` from `android/key.properties`
  (template: `android/key.properties.example`), and **refuses** to build a release APK without it
  unless `-PallowDebugSigning=true` is passed on purpose.
- **A warning was not enough — measured, not assumed.** `flutter build apk` prints its own two lines
  and swallows Gradle's `logger.warn`, so the one place a warning mattered was the one place it was
  invisible. A Gradle `error()` does reach the user. Both branches were built here: with a throwaway
  key, `apksigner verify --print-certs` reported that key's DN on the produced APK; without one, the
  build failed with the message and exit code 1.
- The key and its passwords cannot be committed: `android/.gitignore` **and** the root `.gitignore`
  both exclude `key.properties`, `*.jks`, `*.keystore` (`git check-ignore -v` names the matching rule).
- **The migration, named rather than buried**: every shop on a debug-signed build must **uninstall**
  before the first signed release installs. What is lost is only what lives on that phone (the saved
  session and any unsynchronised sale) — the account and its data stay on the server. That note is the
  first thing `download.html` says.

### 2. A download page that cannot guess
- `public/download.html` (public, served by the existing `express.static`): reads
  `GET /api/app/release` for the version, the notes and the hash, then shows the install steps and the
  verification command. Bilingual **by an EN/FR swap rather than a `.fr` twin** (privacy/terms have
  twins): the page is dynamic, and duplicating the fetch would be two places to drift.
- `APP_APK_SHA256` joins the announcement (`utils/appRelease.js`): validated as exactly 64 hex
  characters and lower-cased. A hash that is *nearly* right is refused rather than shown — a number
  that looks authoritative and is wrong teaches a shop to stop checking.
- Nothing configured still means `known: false` and a page that says so instead of inventing a version.

### Validation
- Backend **50 suites / 668 tests** (app-release suite 13), `node --check` clean; Flutter **539 tests**,
  `flutter analyze lib` **0 errors** (no Dart changed: the APK build compiled it). APK 82.3 MB,
  ~8 min cold, ~24 s warm.

### Still open (named, not pretended)
- **Owner action**: create the real key once (`keytool`, then back it up — losing it means every shop
  uninstalls), publish the first signed APK, set the six `APP_*` variables on Render and deploy. A push
  does not deploy; `GET /health`'s `RELEASE` marker is the proof.
- The debug-signed builds already in the field cannot be upgraded **to** anything; the first signed
  release is a reinstall, which is why its notes should say so.


## 2026-11-10 — Three defects in the same day's work, and what "lazy" actually meant ✅

Auditing what the day shipped, rather than trusting it. Each defect was reproduced before it was fixed.

### 1. A mandatory notice stacked dialogs on top of itself
- `AppUpdateProvider.check()` notifies **twice** — once when the request starts, once when it answers — and the host re-arms a mandatory notice on every notification. So the second notification pushed a **second** dialog over the one on screen: tapping *Later* still left a dialog behind.
- A `_dialogOpen` guard (set before `showDialog`, cleared in `finally`) closes it. The first attempt at that edit left the `try` unclosed, and `flutter analyze` said so before the tests did.

### 2. The download page, run instead of read
- A **failed or unknown fetch left a disabled button pointing at `#`** — a dead control on the one page a shop uses to get the file. It is hidden now, and comes back when a release is known.
- **CSS trap:** `.btn` sets `display`, which beats the user agent's `[hidden]` rule, so the button the script hid would still have been laid out. `.btn[hidden]{display:none}`.
- The page's script is now covered by **`tests/app_release_page.test.js`** (10 Jest tests across the four states, EN and FR): `node --check` only ever proved syntax, and reading it missed all of this.

### 3. The report constructed every drink card, every build
- `pour_cost_report_screen.dart` spread `report.map(_drinkCard)` into a plain `ListView(children: [...])`, so **every** card widget (a Card + InkWell + a dozen Texts + its formatted strings) was allocated on each build — a shop with 200 drinks paid for all 200 before seeing the first, and again on every period change and provider notification. Now a `ListView.builder`: preamble as item 0, pixels unchanged.
- **The scope, stated honestly:** both forms lay their **elements** out lazily, so the win is the per-build widget construction, not layout. The first version of the regression test counted rendered rows and would have passed for *both* implementations — it was rewritten to assert the delegate is a `SliverChildBuilderDelegate`, the property that actually distinguishes them, with a throwaway probe proving the assertion discriminates the two forms.

### Validation
- Flutter **540 tests**, `flutter analyze lib` **0 errors**, backend **51 suites / 678 tests** (the page's script is a committed Jest suite), `node --check` clean.

### Recorded, not fixed
- `variance_screen.dart` carries the same eager pattern (`ListView(children:)` over per-drink rankings). It is an unfamiliar multi-section screen, so it is named as the next candidate rather than restructured unasked.
- A release put away with *Later* stays away for the session even if a **newer** version is announced later in that session (`_dismissed` is per-session by design). Left as designed; flagged because it is a decision, not an accident.


## 2026-11-10 — Two things that never worked: the offline banner, and "reset by security" ✅

### 1. The offline banner was mounted and could not appear
- `build()` returns the bare child while `_isChecking` is true, and that flag started true. Only two paths ever cleared it, and both could be skipped: `_checkConnectivity()` had **no try/catch** (on a platform where the connectivity plugin throws, the flag stayed true for the whole session), and `_checkConnectionQuality()` **returned early on a non-200 `/health`** and swallowed timeouts and socket errors in its catch.
- So the everyday case at a till — *"Wi-Fi connected, no internet"* — produced no banner and no explanation. A failed probe is now the offline signal, every exit clears the flag, and the toasts fire on the transition only (the 10-second probe could repeat them).
- **Placement, measured:** `containers_screen` and `purchasing_screen` wrap their Scaffold **body**, so the banner sits under the AppBar as intended. In `main.dart` it wraps the whole `CalculatorScreen`, so there it draws at `top: 0` — **over the calculator's AppBar, covering the drawer button while it is visible**. Not changed, because the global alternative is worse: mounted in `MaterialApp.builder` it would cover *every* screen's AppBar (it is `Positioned(top: 0)` and its `SafeArea` only accounts for the status bar). **Decision of record: to show it on another screen it must wrap that Scaffold's body**, as those two do.

### 2. "Reset with my security questions" could never work, anywhere
- **The app**: `AuthProvider.resetPassword` was a stub — `// ... existing reset password code ...` followed by `return false;`. It ignored every argument, made no request, so the screen answered *"those answers are wrong"* no matter what the shop typed.
- **The backend**: no such route existed; the only implementation lived in `controllers/auth.controller.js` (Mongoose), which nothing requires — dead since the Postgres rewrite. The answers *were* stored at registration all along (`users.security_question1/2`).
- Now: **`POST /api/auth/reset-password-with-security`** (username **and** email both required — either alone is a guessable half), comparing through a new pure `utils/securityAnswers.js`: trimmed, case-folded, inner whitespace collapsed, and **an empty stored answer refuses the reset** rather than matching an empty attempt. Wrong answers land in the same `password_reset_requests` store as the emailed code and lock after five tries for fifteen minutes.
- **Both** reset routes now revoke the account's sessions (`is_active = false` + cache). A reset that leaves the old sessions alive is not a reset.
- App side: `BackendAuthService.resetPasswordWithSecurity` posts the answers and returns the server's message and status; the provider delegates to it.
- Verified: `tests/security_answers.test.js` (**8 Jest tests**), backend **52 suites / 686 tests**, `node --check` clean, `flutter analyze lib` **0 errors**, `flutter test` **540**.

### Still open (named, not pretended)
- A 429 ("too many attempts") still reaches the screen as the generic *"those answers are wrong"* text; showing the server's own words in French needs two new i18n keys, deliberately not guessed at here.
- The app-side wiring has no test: `BackendAuthService` calls the global `http.post`, so it cannot be handed a `MockClient` without injecting a client. The rule itself is tested on the backend, where the decision is made.
- The emailed-code path is implemented with daily caps and a wrong-code lock, but it needs `SENDGRID_API_KEY` on Render: unset, no code is ever delivered, and nothing in the app can tell that from a wrong address.

## 2026-11-11 — A refund follows the money: cash stays cash, CamerPay stays CamerPay ✅

### The gap this closes (it was named in this file on 2026-10-11)
> "a refund is always assumed to be cash out of the drawer — there is no 'credit note
> instead of cash' option yet."

Both halves were real and they pointed opposite ways:
- `POST /orders/:id/refund` **never received a method** from the app, so `buildRefundRow`
  filled in its default `'card'` — **every** refund was recorded as a CamerPay card refund,
  including a cash one;
- every return was subtracted from `expectedCash`, so refunding a **mobile-money** sale
  produced a shortage a cashier could not explain;
- and the root of both: `orders` had **no `payment_method`**, and the only trace of a
  CamerPay collection (`payment_transactions`) is not reliably linked to the order — the
  mobile-money path passes a millisecond timestamp as `orderId` *before the order row exists*.

### What now happens
- **`orders.payment_method`** (boot migration + `sql/orders_payment_method.sql`): the till
  writes its `PaymentMethod.name` when it creates the sale, so the fact survives.
- **One lane rule**, mirrored on both sides — backend `utils/refundRecord.js`
  (`canonicalMethod` / `isCashMethod` / `refundLane`) ↔ app
  `lib/utils/refund_lane_helper.dart`. `mtn_momo`, `MTN MoMo` and `mtnMobileMoney` are one
  rail; `visa` / `stripe` are card; anything unreadable keeps the **provider** assumption —
  never cash, because filing a CamerPay collection as cash hides money the drawer was never
  responsible for.
- **The refund dialog knows the lane**: it is read from the sale, not chosen, so it is
  titled accordingly ("Cash refund — from the drawer" / "Refund at CamerPay"); the
  provider-reference field is offered **only** on the CamerPay lane (asking on a cash refund
  only invites an invented one); the method about to be stored is spelled out before the row
  exists; and the audit detail reads `from the drawer` or `via mtn (ref …)`.
- **The cash-up only pays for its own lane**: `GET /orders/:id/returns` and both shift
  queries join the order's method onto the return ledger, `summariseReturns` now reports
  `cashReturnValue` / `providerReturnValue`, and `expectedCash` subtracts **cash only**.
  `netSales` still nets off both — the sale really did shrink. A ledger row with no method
  (older data) keeps the historical cash reading, so a report never changes meaning because
  the column is new.
- The return dialog names the lane too, so "Return everything left" cannot imply the drawer
  paid for a mobile-money sale.

### Deliberately NOT done (and why)
- **No automatic CamerPay refund call.** `utils/campay.js` already exports an unused
  `refundPayment()` and CamerPay documents `POST /payment/{uuid}/refund` — but its documented
  API is **FULL refunds only**, while this app's whole return flow is built for partials
  ("1 of 2 comes back"). Firing it from a return could over-refund, irreversibly. The money
  keeps moving where it belongs (the CamerPay dashboard); what was actually broken was that
  the app never said *which* lane a refund belonged to, and now it does.
- A **credit note** (money owed instead of money back) is still not an option. This split is
  the groundwork for it.

### Validation
- Backend **52 suites / 697 tests** (+11: refund lanes, the drawer split, `canonicalMethod`)
  · `node --check` clean · Flutter **551 passed** (+7, `test/refund_lane_test.dart`) ·
  `flutter analyze lib` **0 errors** · i18n **EN=1536 FR=1536** (+7 keys in both maps).
- **Pre-existing red, not this task:** `test/plan_provider_session_test.dart` ("signing out
  leaves no plan on the device") fails deterministically on its own. It belongs to the
  uncommitted `lib/providers/plan_provider.dart` work already in the tree: `setSession(null)`
  early-returns when `_sessionKey` is already `null`, so a seeded provider never resets on
  logout. Left untouched.


## 2026-11-11 — "Is the printer connected?": the Bluetooth printer now answers before you print ✅

### The gap, stated plainly
`ReceiptPrintScreen` gave the shop ONE moment of feedback: a toast *after* the bytes
were written. There was no printer status anywhere — a cashier could not tell whether the
printer was on, paired, connected or simply out of range, and the only way to find out was
to lose a receipt. The flow also re-asked "which printer?" on every single print (nothing
was remembered) and **disconnected immediately after writing**, so the app could not even
have answered "connected" if it had wanted to.

### What now happens
- **A status card at the top of the receipt screen**, on open: the state in words
  (Bluetooth off / no printer paired / not connected / connecting / **connected** /
  not responding), coloured, with the **device name** next to it. Below it, the sentence
  that says what to DO — "Pair the printer once in Android Settings → Bluetooth, then tap
  Find printers", "Turn Bluetooth on, then tap Connect", "Check that the printer is
  switched on, charged and in range".
- **The printer is remembered on the device** (`receipt_printer_mac` / `_name` in
  SharedPreferences) and **reconnects itself on open**, so the daily flow is: open →
  "Printer connected · Xprinter XP-58" → print. Deliberately *not* company-scoped cache: the
  till keeps the same physical printer whoever signs in, so it survives a sign-out the way
  the device PIN does.
- **A Test slip button** (only when connected) prints a translated slip — headline,
  "Printer is connected", the date, "No sale was made." — so paper, feed and connection can
  be proved *before* a real receipt is at stake. The service builds the ESC/POS bytes; the
  screen passes the already-translated lines, so the service still holds no copy.
- **The connection is held open** rather than dropped after each write, and a failed write
  now flips the card back to "Printer not responding" instead of leaving a stale "connected".
- **Connect / Disconnect / Change printer / Check again** are explicit buttons, and the
  picker marks the printer in use with a check and falls back to the **MAC address** as the
  label — thermal printers very often report an empty name (or a bare `?`), and "Printer"
  tells nobody which machine is on the shelf.
- A saved printer that is no longer paired is matched against what is paired *now*, so the
  screen says "your saved printer is no longer available — please choose one" instead of
  failing silently.

### Where the logic lives
- `lib/utils/printer_status_helper.dart` (new, pure): `derive()` turns the raw plugin facts
  into one `PrinterState` — with **Bluetooth off outranking a refused permission**, because
  Android reports the permission as missing while Bluetooth is off and "switch Bluetooth on"
  is the only instruction a shop can act on — plus `findRemembered`, `deviceLabel`,
  `titleKey`/`hintKey`, `canAttemptPrint`/`needsSetup`/`isReady`.
- `lib/services/receipt_printer.dart`: the pipeline is split into `hasBluetoothPermission`,
  `isBluetoothEnabled`, `pairedPrinters`, `isConnected`, `connect`, `disconnect`, `writeBytes`
  and `buildSlipBytes` — the old connect→write→disconnect single call is kept for callers that
  print in one go, but no longer hides the connection.
- 27 new EN/FR keys, all under `printer*`.

### Validation
- Flutter **561 tests** (+10: `test/printer_status_test.dart`, which also pins that every
  state has a title AND a hint that says something different from it).
- `flutter analyze lib` **0 errors**, 493 issues — unchanged, so no new lint debt.
- i18n **EN=1563 FR=1563**.
- Not device-verified: the Bluetooth handshake itself needs a real printer, so the plugin
  calls are covered by their failure paths (`try/catch` → a false flag → a named state), not
  by a test. The status logic around them is fully tested.
- **Pre-existing red, not this task:** `test/plan_provider_session_test.dart` still fails
  alone (the uncommitted `plan_provider.dart` work in the tree).


## 2026-11-11 — Scan to sell (single AND batch), and a plan that stops following the previous user ✅

### 1. A scan can sell one unit or a whole pack
The sell sheet on the scanner offered a **guessed ladder** of chips — 1 / 6 / 12 / 24 / 48 —
so a 12-bottle crate was offered "24" and a drink sold by the glass was offered "48". The
pack size is a property of the DRINK (`unitsPerPack`, entered once in the catalogue), and
`_restock` already used it; the sell path did not.
- **`lib/utils/scan_sell_helper.dart`** (new, pure): `options()` returns the single unit
  plus the drink's **own** pack when it is more than one, `packSize()` never drops below 1
  (a bad catalogue value must not offer "0"), `isWholePack()` recognises a batch however it
  was typed, and `exceedsShelf()` is the shelf note.
- The sheet now reads: `[ 1 · Single unit ] [ 24 · Whole pack ]` — labelled, from the
  product, with the stepper still there for any other number. Verified by
  `test/scan_sell_test.dart` (8 tests), including that **24 never appears for a 12-pack**.
- The shelf warning is now **words** ("The shelf holds 6") instead of a bare icon+number, and
  it stays a note: the sale stands, because the server is the only authority on stock.
- 3 new EN/FR keys (`scanSellSingle`, `scanSellPack`, `scanShortOnShelf`).

### 2. The subscription no longer belongs to the device
**Reported:** a Starter shop logs out, a Pro user signs in on the same till, and the Pro user
has to open the subscription screen before their own plan appears.

**Two separate causes, both real:**
1. **A fresh login never re-bound the plan.** `setSession(key)` + `refresh()` lived inside
`_loadCompanyDataWithCleanup`, which is called from `_initializeApp` **only** — i.e. on app
launch. So after a logout/login on a *running* app, nothing re-asked who had signed in, and
the gate was left holding the previous session's state.
2. **A failed fetch was recorded as an answer.** `refresh()` set `hasLoaded = true` in a
`finally` whether or not the server replied, so "we could not find out" became "you are on
Free" — and the gate's rule 4 (`hasLoaded && !planActive`) sent a paying company to the plans
screen. Opening the subscription screen refreshed again, which is why the plan appeared only
after the user went there by hand.

**The fix, in layers:**
- **`PlanProvider`** gains `resolved` / `fetchFailed` next to `hasLoaded`, so "we are done
  asking" and "we know the answer" are distinct; `refresh()` coalesces concurrent asks (the
  login handler and the gate ask at the same moment) and, when the first ask fails, retries
  **in the background** (3 tries, stops on success, on a session change, or if nobody is
  signed in) — the plan now arrives by itself.
- **`setSession(null)` really clears.** The early return used to fire for `null -> null`, so a
  provider that had been seeded (or whose session was never recorded) kept one shop's plan
  through another shop's logout. Signing out now drops the plan, the `hasLoaded` flag **and**
  the administrator bypass — discarded, not hidden.
- **`main.dart` binds the plan to the SESSION, once per session**, from an `AuthProvider`
  listener registered in `initState` — covering the cold start *and* an interactive login with
  one rule, and clearing on logout. It is deferred to after the frame on purpose: the plan is
  dropped **before** `PlanGate` mounts and decides, so the gate can never judge this user on
  the previous user's answer. The duplicate binding in the cold-start loader is removed.
- **`planGateDecision` takes `fetchFailed`** and returns `proceed` — a plan we could not READ
  is not a plan that is Free. This is a UX default, not a security hole: every paid route is
  still refused by the backend's `requirePlan`, which reads the session and never trusts the
  app. The alternative — asking a paying company to buy what it already owns — is the worse
  mistake, and the state is temporary because the fetch retries.

### Validation
- Flutter **573 tests, ALL PASSING** (the task fixed the one that was failing) · `flutter
  analyze lib` **0 errors**, **492** issues (one fewer than before) · i18n **EN=1566 FR=1566**.
- New/extended: `test/scan_sell_test.dart` (8), `test/plan_gate_test.dart` (+2: a failed fetch
  proceeds, a *successful* Free answer still shows the plans), and
  `test/plan_provider_session_test.dart` now green (its "signing out leaves no plan on the
  device" case is exactly cause 2, and the `setSession` guard is its fix).
- Backend untouched this round.


## 2026-11-11 — Faster cold start, without moving the security boundary ✅

### What was slow (measured by reading the path, not guessed)
`_initializeApp` was **fully serial**, and the splash covers all of it (`_isCheckingAuth` is
only cleared at the very end). On an authenticated start the app made these calls **one after
the other**, each one waiting for the last to answer before it even started:

1. `checkBackendConnection()` — inside `autoLogin()`
2. `_validateCurrentSession()` — inside `autoLogin()`
3. `checkSessionValidity()` — **the same method again**, from `_initializeApp`
4. `_loadUserSettings()` (settings)
5. `loadDrinksFromSupabase()`
6. `loadOrdersFromSupabase()`
7. `loadInventoryFromSupabase()`
8. (Staff, when the list came back empty) inventory, all over again

…plus the expiry alert (forecast + storage + notification) awaited before the first frame.

### What changed (4 surgical edits, all in `lib/main.dart`)
- **🚀 The catalogue is fetched in PARALLEL.** Settings, drinks, orders and inventory are
  independent, so they are issued together with one `Future.wait` — the splash waits for **one
  round trip instead of four more after it**. The two orderings that genuinely matter are kept
  explicit: the order *cache* is read locally first (history on screen even on a slow link), and
  `setDrinkProvider` still runs only after both drinks and inventory have arrived.
- **The duplicate session check is gone — and it is provably not a weakening.**
  `checkSessionValidity()` is literally `return await _validateCurrentSession()`, the method
  `autoLogin()` runs two lines earlier. It is now only repeated when `sessionValid` is false
  (no stored token, or offline), so a session is still verified **exactly once per start,
  before the first frame, and never trusted from a previous run**. One round trip saved with the
  security boundary untouched.
- **The expiry alert is off the critical path** (`unawaited`): it needs no network, but it does
  real work — a forecast, storage reads, a notification — and none of it is needed to take a
  sale.
- **The money helpers keep an offline-safe order.** `CurrencyHelper.refresh()` /
  `PaymentHelper.refresh()` are *local* preference reads, so they still run before the network
  (an offline start formats money correctly); `_loadUserSettings` joins the parallel fan-out,
  and the two are re-read once it lands, so **this session's** settings decide the formatting.

Result, as a sequence of network phases: **7 serial calls → 2** (the auth pair, then one
parallel fan-out).

### What a fast start does NOT do here (deliberate)
The splash still waits for the catalogue. Rendering the calculator *before* the data lands
would show an empty drink menu — which reads as "the app is broken", not "the app is fast".
Doing that properly needs a real cache-first pass in the providers (drinks are network-only
today: `DrinkProvider`'s cache load runs in its constructor, before a company context exists).
Named as the next step, not pretended.

### The rest of "fast" is hosting, not code
- **Render free tier spins down after ~15 min idle** (`render.yaml` has `plan: free` and one
  instance) — a cold start is 30–60 s and dwarfs everything above. A keep-alive hit on
  `/api/ping` every ~10 minutes, or a paid instance, removes it.
- **`UV_THREADPOOL_SIZE=8`** on Render matches the login queue that already exists
  (`authQueue = createQueue(AUTH_CONCURRENCY || 8)`), so a login storm finishes sooner.
- `autoLogin()`'s own `checkBackendConnection()` → `_validateCurrentSession()` pair is still
  serial. Left alone on purpose: it is what puts the app into offline mode, and folding the two
  would change that behaviour for one round trip.

### Validation
- Flutter **573 tests, all passing** · `flutter analyze lib` **0 errors**, **492** issues
  (unchanged — no new debt) · i18n **EN=1566 FR=1566** (no new keys).
- Verified by inspecting the resulting call order in `main.dart` (autoLogin → reuse-or-check →
  local money helpers → order cache → **parallel fan-out** → re-read money helpers → reloaders →
  `setDrinkProvider` → unawaited expiry alert).


## 2026-11-12 — Security hardening: the audit's P0/P1/P2 fixes ✅ (part 1)

A full sweep — repo, git history, live backend, live database — produced five fixes, each
verified. What is still owed is listed at the end, so nothing here reads as "closed".

### 1. A credential-bearing script was tracked in a PUBLIC repo 🔴
`scripts/live_smoke.js` was **tracked**, and `github.com/mdksako-eng/Drink_Quick_Cal` serves
the repo **publicly** (HTTP 200, "Public", 280 commits). `.gitignore` **already** listed it —
a rule added later does not untrack what is already committed, and `debug_login.js` /
`reset_test_pwd.js` were correctly never tracked, so only this one slipped through.
- **Fixed:** `git rm --cached` (local file untouched, still ignored).
- **Still owed (owner):** history still contains it. Because the repo is public, **rotate
  whatever the script authenticates with** — that is what makes the exposure harmless — then
  purge it from history (`git filter-repo`) or accept it and rely on the rotation. Enable
  GitHub secret scanning + push protection. The file was **not opened** (`.clinerules`
  forbids it) and no literal secret matched my pattern scan, so its contents are
  **unconfirmed** — treat as exposed.

### 2. Dependencies: the HIGH advisories are gone 🟠
Prod audit before: **8 vulnerabilities (4 low, 1 moderate, 3 high)** — body-parser (DoS),
follow-redirects, mongoose (×4 advisories), qs.
- `npm audit fix` (non-breaking): 13 packages changed → **4 low** remain.
- **`mongoose` deleted from `dependencies`**, 18 packages pruned: provably dead — nothing in
  `server.js` requires `controllers/`, `models/`, `database.js` or `utils/validators.js`, and
  no test touches them. An unused dependency is pure attack surface.
- **Still owed:** `deepmerge` (via `@sendgrid/*`) needs `npm audit fix --force`, which
  downgrades `@sendgrid/mail` to 6.5.2 — a decision, not a blind fix.

### 3. The 12 MB body limit is no longer global 🟠
`express.json({limit:'12mb'})` applied to **every** route, so the *unauthenticated* ones
(login, password reset, webhooks) parsed up to 12 MB of attacker-chosen bytes before any
check ran — exactly where body-parser's advisory lands.
- Now `/api/ai` gets `12mb` (mounted **first**) and everything else `1mb` (JSON and
  url-encoded): `express.json()` skips an already-parsed body. Verified safe — `base64Encode`
  appears in exactly one Dart file (`ai_assistant_screen.dart`), so the AI routes are the only
  large senders. `verify` was extracted to `captureRawBody` and passed to **both** parsers so
  webhook HMACs keep their raw bytes.
- `/health` now reports `'1mb (12mb on /api/ai)'` instead of a stale `'12mb'`.

### 4. Boot migrations no longer race `app.listen` 🟠
The startup IIFE closed at line 1038 while `app.listen` sat at 3741, **outside it**, with
nothing awaiting it: migrations ran while traffic was already accepted. With
`orders.payment_method` verified **MISSING** in production, the next deploy's boot `ALTER`
would have landed in that window and failed a first order (*column does not exist*).
- Fixed with the minimum diff: `const bootstrapReady = (async () => {` and
  `bootstrapReady.catch(...).then(() => openPort())`, the existing `app.listen` block wrapped
  unchanged in `function openPort()`. A failed bootstrap still opens the port (degraded)
  rather than leaving the shop offline, and logs why.
- `RELEASE` → **`2026-11-12-hardening`**, so `GET /health` proves the deploy.

### 5. Android backup disabled 🟡
No `android:allowBackup` was declared, so it defaulted to **true**, letting cloud/adb backup
lift the SharedPreferences caches (company name, orders, customers) off a till. Now
`android:allowBackup="false"`; the trade-off is a cold local cache on a new phone, which
re-syncs at login.

### Validation
Backend **52 suites / 697 tests** after every change · `node --check` clean · Flutter **573
tests passed** · `flutter analyze lib` **0 errors** · manifest parsed with `[xml]` →
`allowBackup='false'` · prod audit 8 → 4.

### Still open (named, not silently dropped)
- **Rotate + purge** `live_smoke.js` (owner action).
- `deepmerge`/SendGrid — the breaking decision.
- **`orders.payment_method` is still missing in production**: the refund-lane work is
  unshipped until the next deploy (the race that endangered it is now fixed).
- **Render free instance sleeps** (measured: first `/health` 503, then `uptimeSeconds: 102`).
- `helmet` is installed but **never used** — adding it needs `contentSecurityPolicy: false`
  (public pages use inline styles) plus a smoke test of those pages, which needs credentials
  this machine does not have.
- Data hygiene: orphan Manager (`id=26`, no company), 1 unverified account, `doppel` deposit
  1.00, 101 legacy guessable session tokens (all inactive).
- **Verified healthy:** 29/29 tables RLS-enabled, zero policies, no `anon`/`authenticated`
  grants · 0 plaintext passwords · CamerPay credentials ciphertext-only · no duplicate
  emails · no stale active sessions · no NULL-company orders/drinks · no SQL interpolation ·
  every payment route guarded or signature-verified · no `.env` in 1,456 commits.

### 2026-11-12 (later) — helmet, and the legacy session-token cleanup
- **Security headers are now sent.** New `utils/securityHeaders.js` + `tests/security_headers.test.js`
  (**7 tests, no database needed** — a throwaway express app wears the real middleware and the
  assertions are made on real response headers). Kept: `X-Frame-Options: SAMEORIGIN`, nosniff,
  HSTS, `no-referrer`, `Cross-Origin-Resource-Policy: cross-origin`. Deliberately **off**:
  **CSP** (the public legal/download pages use inline styles/scripts — a default
  `default-src 'self'` would leave them broken) and **COEP** (blocks cross-origin subresources
  and buys nothing for a JSON API).
- Two things the test taught, both now pinned in code: helmet v8 defaults X-Frame-Options to
  **SAMEORIGIN, not DENY** (the assertion was wrong first — the test caught my assumption), and
  **`Object.freeze()` is shallow**, so the nested resource policy is frozen too or the
  immutability guard is theatre.
- **101 legacy guessable session tokens deleted** (`token_<id>_<ts>`, 21-char). The predicate
  was guarded to legacy format **AND** inactive **AND** expired, so a live session could not be
  touched even in principle. Verified in a **separate** statement: sessions **354 → 253**,
  legacy remaining **0**, all 253 are 67-char `sq_` tokens, **active sessions still 1**
  (length 67), 0 stale active — nobody was logged out.
- *Lesson kept: a data-modifying CTE's effects are invisible to the rest of its own statement,
  so an "after" count inside the same query reads the pre-delete snapshot and proves nothing.
  The verification must be its own query.*
- Validation: backend **53 suites / 704 tests** (+1 suite, +7 tests), `node --check` clean.
- **Still owed / not touched:** the `doppel` deposit needs the shop's number (not a guess); the
  orphan Manager (`id=26`) and the unverified account are untouched — deactivating a user
  account is the owner's decision, not a cleanup I should make on their behalf.

### 2026-11-12 — the 99-unit ceiling, and container types that could not be seen

**1. A wholesale shop could not type, dictate or scan more than 99 units.**
The cap was in **six** places with **two different answers**: the calculator capped at 99 four
times (the typed field, its `1 - 99` helper text, and both `+` steppers) and the dictates capped
at 99 twice (`voice_service.dart`, `ai_order_parser.dart`) — while the scanner's
send-to-calculator already allowed **999**. A crate sale is 24 and a wholesale drop is hundreds,
so `120` silently became `99`.
- Now **one rule**: `lib/utils/order_limits.dart` — `maxQuantity = 999` and `clampQuantity()`,
  used by the till, both dictates **and** the scanner (whose private `999` now reads from it).
  `test/order_limits_test.dart` (6 tests) pins the ceiling, the floor, and that unreadable text
  becomes 1 rather than 0.
- **A pinned test changed on purpose:** `ai_order_parser_test.dart` asserted `'9000 beer' → 99`;
  it now asserts **999**. Recorded here because changing an assertion is a behaviour change, not
  a test fix.
- **Why 999 and not unlimited:** the cart stores **one entry per unit** (`Order.items` holds the
  drink once per unit — that is what the invoice, the stock ledger and the history read), so the
  request body grows with the quantity. 999 keeps one line near 200 KB, inside the 1 MB JSON
  limit set earlier today. Selling more than that in ONE line needs the payload to carry a
  quantity instead of one entry per unit — a real change, deliberately not faked with a bigger
  clamp.

**2. The registered container types appeared nowhere in the app.**
`GET /containers/outstanding` filters `byType` to types with a **non-zero** outstanding, and the
screen only rendered its "Out by container" section when that list was non-empty. With no
movements recorded (the live table had 0), the section never appeared — and the empty state hid
the “Add a container” button because the shop *did* have types. So `harp` and `doppel` were
reachable only from inside a movement dialog.
- The screen now **always** shows a **Container types** section: every registered container with
  its deposit, which is the shop's own catalogue rather than a balance. A manager taps a row to
  re-price it.
- The **name is read-only while editing**, on purpose: `POST /containers/types` finds the row
  **by name**, so editing the name there would create a *second* container instead of renaming
  the first. A real rename needs the endpoint to take an id — named as the next step, not faked.
- 1 new EN/FR key (`contTypes`); the existing `edit` label titles the edit dialog.

**Validation:** Flutter **579 tests** (+6) · `flutter analyze lib` **0 errors**, 493 issues (492
before; every issue in the changed files is pre-existing — a `use_super_parameters` and three
deprecated `speech_to_text` params — and I could not attribute the +1 to a line, so it is not
claimed away) · i18n **EN=1567 FR=1567** · backend untouched.




## The AI screen — a photo is read, not guessed; and the replies were translated all along — 2026-11-12 (`85ceb4d`, `12decba`, `9a845c5`)

**The photo path now reports instead of guessing.** Three fixes with one theme.

- The image instructions told the model to use the menu names *"exactly as written above when they
  match"* and said nothing about anything else — which reads as "drop it". A drink the shop does not
  sell, or one the model garbled slightly, vanished with no trace: the reply said *"Added: 2 x Beer"*
  and the shop could not tell a **bad photo** from a **missing catalogue entry**. The instructions now
  also say to include an off-menu drink spelled as it appears in the photo, to **admit** a line too
  faint or cropped to read instead of guessing it (a hallucinated name silently adds stock nobody
  ordered), to use **1** when no quantity is written, and to emit no `ORDER_JSON` at all when the
  photo holds no order. These lines decide whether the AI understands a receipt, so they live in
  `utils/aiVisionPrompt.js` with `tests/ai_vision_prompt.test.js` (12 tests) rather than inline in
  the route.
- `AIOrderParser.unmatchedLines()` returns what the model read that matches no catalogue drink, and
  the chat prints it as *"⚠️ Not in your catalogue: 3x Fanta"* (+5 tests). Same on the typed
  `ORDER_JSON` reply path — where the warning goes on the visible message only, never into the
  history fed back to the model.
- **The capture was tuned for the wrong job:** `1024px / JPEG q60`, commented *"the AI only needs the
  drink names"*. That is fine for a printed menu and marginal for handwriting and receipts, where q60
  blurs thin pen strokes and 1024px shrinks an A4 note until the small writing is unreadable —
  precisely what people meant by *"the AI did not understand my photo"*. Now **1600 / q80**,
  ≈250–450 KB, still negligible against the 12 MB the vision route allows.
- A **permanently denied** camera permission returned the same first-time toast, so every later tap
  looked like a broken button. It now explains and offers the system settings screen.

**The replies were English only — and the translations already existed.** Every stock, price,
recommendation, checkout, clear and connection answer was hardcoded English in a bilingual app that
also *speaks* its replies. `lib/utils/i18n.dart` already held the whole set (`ai_takingToCheckout`,
`ai_stockInfo`, `ai_currentStock`, `ai_priceInfo`, `ai_costLabel`, `ai_profitPerUnit`, `ai_priceList`,
`ai_recommendationsHeader`, `ai_checkAvailable`, `ai_noDrinksInInventory`, `ai_troubleConnecting`,
`ai_noOrdersToCheckout`) and **nothing referenced any of them** — written, reviewed, then forgotten
while the screen kept building its own strings. They are wired up now: **no new keys at all**,
`i18n.dart` byte-identical, and the "in stock" tag reuses `calcLeftInStock` rather than becoming a
fourth copy of the phrase. ⚠️ **The first attempt added 14 keys and did not compile:** `ai_orderCleared`
was already defined and a duplicate key in a `const` map is a **compile error**. Parity passed (both
maps agreed), the build failed, and every test file then failed to *load* rather than *fail*.
**Grep a key name before adding it.**

**And the assistant could not answer in the right language, because nobody had told it which one.**
The system prompt now asks for the user's language — the reply is both shown and read aloud.

**The voice follows the app language until the user chooses otherwise.** The TTS language fell back to
a hardcoded `'en-US'` whenever the shop had never opened the voice settings, so a French shop heard
French replies read in an English voice. `VoiceService.resolveTtsLanguage({stored, appLanguage})` is
the one tested decision (6 tests): a stored choice always wins, a blank stored value counts as none, a
bare `fr`/`EN` normalises, an unknown language falls back to English. A mid-session language switch
moves the voice too; confirming the voice settings makes the choice explicit.

**Deploy:** the backend is live on **`2026-11-12-hardening`** (`GET /health` on
`drink-quick-cal-kja1.onrender.com` — `jsonBodyLimit: 1mb (12mb on /api/ai)`, database connected), so
the boot migration adding `orders.payment_method` has run: the port only opens after
`bootstrapReady` resolves. The column itself could **not** be confirmed from this machine — the local
`.env` holds **no `DATABASE_URL`** (dotenv injects 0 vars), so `scripts/inspect_schema.js` cannot
connect. Owner: check the Render boot log for the migration line.

**Validation:** Flutter **590 tests** (+6 voice language, +5 `unmatchedLines`) · `flutter analyze lib`
**0 errors**, 493 issues · i18n **EN=1570 FR=1570** · backend **54 suites / 716 tests** (+1 suite, +12
for the vision prompt).


## The download page moves to Cloudflare Pages — the front door stops sleeping — 2026-11-12

- **Why:** the page a new shop opens to get the APK was served by the backend on the **free Render
  instance that sleeps after ~15 min idle** — measured on this project as a **503 on the first
  request**, then ~100 s to warm up. A front door that can time out before it shows anything is the
  wrong front door. It is now a self-contained static site in **`download-page/`** (`index.html`,
  `logo.png`, `_headers`, `_redirects`, plus **`wrangler.jsonc`** at the repo root and the runbook
  **`DOWNLOAD_PAGE.md`**) served by **Cloudflare Workers static assets**: always on, and it needs
  **no backend change**, because the release API already answers `Access-Control-Allow-Origin: *` — **verified
  against production with an `Origin` header**, not inferred from `app.use(cors())`.
- **The page is static; the metadata is not.** The version, the notes and the SHA-256 come from
  `GET /api/app/release` (the backend's environment stays the only source of truth — the page still
  never invents a version), so exactly one line ties the two hosts together: `API_BASE` in
  `index.html`.
- **A third state, because two different failures were sharing one sentence.** Before, *"the server
  says nothing is published"* and *"the server did not answer"* both rendered as *"No build is
  published yet."* — so a sleeping instance read as a fact about the release. Now the API's own
  `known:false` says no build is published, while an unreachable API says **"Could not reach the
  download server just now. This page is fine — only the version check failed."** with **Check
  again** and a link to the GitHub releases page. Two attempts (9 s timeout, one silent retry after
  6 s), because a cold start usually answers on the second.
- **`_headers`** brings the class of headers the backend now sends through helmet (nosniff,
  SAMEORIGIN, a referrer policy, and a CSP pinning `connect-src` to the API host) — a static host
  sends none of these by default.
- **Two things left alone on purpose:** the old `public/download.html` still works (two copies of a
  page drift, so the intended cleanup is a redirect on the next backend deploy — but replacing a
  working page with a redirect to a site that is not live yet is how a front door breaks), and the
  legal pages are **linked, not copied** (a duplicated legal text drifts; the backend keeps the
  published copy, and the link now follows the page language to the `.fr` twin).
- **Validation:** the page was byte-copied from the reviewed original (identical SHA-256) and then
  edited, so all French accents are the original bytes. Then: `data-en`/`data-fr` **23/23 balanced**
  (21 original + 2 new), one `<script>` pair, the document closes cleanly, **`node --check` on the
  extracted inline script exits 0**, the CSP `connect-src` host matches `API_BASE`, and CORS was
  confirmed live. Folder: 20.6 KB page · 114.8 KB logo · runbook · headers.
- **Deployed and verified (2026-11-12):** live at
  **`https://drink-quick-cal.mbundaderick.workers.dev`** as an assets-only Worker (`wrangler.jsonc`,
  no `main`). Checked against the live site rather than locally: `/` **200** (`CF-Cache-Status: HIT`),
  `/download` and `/download.html` **301** → `/`, `/_headers` and `/_redirects` **404** (read, never
  served), `/logo.png` **200** with the intended `Cache-Control`, and CSP / `X-Frame-Options:
  SAMEORIGIN` / nosniff / referrer / permissions headers all present. The French text was verified on
  the live bytes. `workers_dev: true` and **`preview_urls: false`** are now explicit: left implicit,
  every deployed version would stay reachable at its own URL, and for a page that tells a shop *which
  build to install*, a stale copy staying online is the one thing it must not have.
- **Caught by the first build log:** Cloudflare ran `npm clean-install` at the repo root, firing the
  **Render shim's `postinstall`** and installing **177 backend packages** to upload four static files.
  That silently made the front door's deploy depend on the backend's dependency tree. Cloudflare
  documents the fix — build variable **`SKIP_DEPENDENCY_INSTALL=1`** — so the build stops touching the
  backend's packages entirely.
- **Still owner's:** add the custom domain (Worker → Settings → Domains & Routes), set
  `SKIP_DEPENDENCY_INSTALL=1`, then publish a real release — `/api/app/release` still answers
  `known:false`, so both front doors rightly say nothing yet.

