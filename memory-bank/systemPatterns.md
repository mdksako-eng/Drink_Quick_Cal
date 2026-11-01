# System patterns

## Request flow
`screen` → provider (`ChangeNotifier`) → `lib/services/api_client.dart` with a URL
from `lib/config/api_config.dart` → Express route in
`drinks-calculator-backend/server.js` (or a mounted router in `routes/`) →
`requireSession` / `requirePlan` → Postgres via the `pg` Pool.
Supabase direct REST (`supabase_service.dart`) is a secondary/legacy path.

## Live vs legacy code (check before reading)
- `server.js` holds ~36 inline routes **plus** the only three mounted routers:
  `routes/data.routes.js`, `routes/payment.routes.js`, `routes/subscriptions.js`.
- `routes/{auth,drink,order,sync,user}.routes.js`, `controllers/` and `models/`
  (`Drink.model.js`, `Order.model.js`, `User.model.js`) are **not required** by
  `server.js` — treat them as legacy unless you can trace a live import. Do not
  edit them expecting an effect on production.

## Patterns to copy
- **Pure logic extracted for tests**: decision tables and maths live in
  `lib/utils/*.dart` (`plan_gate_logic.dart`, `staff_permissions.dart`,
  `analytics_helper.dart`, `forecast_helper.dart`, `expiry_alert_helper.dart`)
  with mirrored rules in `drinks-calculator-backend/utils/*.js`
  (`staffPermissions.js`). Screens/routes only wire them.
- **i18n**: every user-visible string goes through `t('key')`, `_en` and `_fr`
  kept in parity (962 keys each).
- **Plan gating, two sides**: client `PlanGate` + `plan_gate_logic.dart` resolves
  the plan after login; server `requirePlan` protects the endpoint. Both must
  agree — "Continue on Free" is remembered per company.
- **Offline/sync**: `providers/sync_provider.dart` + `services/storage_service.dart`
  cache locally and replay; `widgets/offline_indicator.dart` surfaces state.
- **Lock / device security**: global overlay `lockOverlayState` rendered above the
  whole Navigator in `main.dart`, plus `lock_service.dart`,
  `secure_storage_service.dart`, `local_auth`, and device-bound session checks.
- **Exports**: data → `lib/utils/analytics_export.dart`,
  `inventory_report_files.dart`, `analytics_report_files.dart` → PDF/Excel/CSV.
  Thermal ESC/POS receipts come from `lib/services/receipt_printer.dart`.
- **Platform gaps**: conditional imports (`*_io.dart` / `*_web.dart` / `*_stub.dart`
  + factory), as in `services/tts/` and `services/os_notifications/`.

## Data
Tables created/used by `server.js`: `users`, `companies`, `user_sessions`,
`subscriptions`, `approval_logs`, `company_join_requests`, `login_requests`,
`app_flags`, `forecast_events`. Business data (`drinks`, `orders`, `inventory`,
`inventory_transactions`, `settings`, `payment_transactions`) is reached through
`/api/data/*`. RLS is applied at boot and by scripts in `sql/` — a new table needs
its RLS script there too.
