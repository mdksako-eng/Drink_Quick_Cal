# Drink Quick Cal — project map

One repo: a Flutter app (`lib/`) plus an Express/Postgres (Supabase) backend
(`drinks-calculator-backend/`). Read this instead of exploring the tree.

## Flutter app — `lib/`
- `main.dart` — entry point, provider registrations, `navigatorKey`, and the
  global lock overlay (`lockOverlayState`) that covers every pushed route.
- `config/api_config.dart` — **all** backend/Supabase URLs (`ApiConfig`).
  Never hardcode a URL anywhere else.
- `models/` — plain data classes (drink, order, inventory, user, forecast,
  analytics, subscription).
- `providers/` — `ChangeNotifier` state: `auth`, `drink`, `inventory`, `order`,
  `plan`, `sync`.
- `services/` — I/O boundary: `api_client.dart`, `supabase_service.dart`,
  `backend_auth_service.dart`, printers, TTS/voice, notifications, storage,
  expiry alerts.
- `screens/` — one file per screen; `widgets/` — shared UI.
- `utils/` — pure, unit-tested helpers: `i18n.dart`, `currency_helper.dart`,
  `price_extension.dart`, `plan_gate_logic.dart`, `staff_permissions.dart`,
  `owner_permissions.dart`, analytics/forecast math, PDF/Excel/CSV exporters,
  `helpers.dart` (`Helpers.showToast`).

## Backend — `drinks-calculator-backend/`
- `server.js` (~100 KB) — one Express app: ~36 inline routes plus mounted
  routers in `routes/` (`data.routes`, `payment.routes`, `subscriptions`).
  The `RELEASE` constant near the top is what `GET /health` reports.
- `middleware/` — `sessionAuth.js` (DB-backed sessions), `planAuth.js`
  (`requirePlan`).
- `utils/` — pure helpers (`staffPermissions.js`, `email.service.js`), each
  covered by Jest tests in `tests/` (Jest + supertest).
- `sql/` — schema and RLS scripts; `scripts/` — operational one-offs.
- Root `server.js` (313 bytes) is only a Render shim that requires the real
  backend — do not put logic there.

## Find before you read
| Question | Look at |
|---|---|
| Which endpoint does the backend serve? | grep the path in `drinks-calculator-backend/server.js` |
| How does the app call the backend? | `lib/config/api_config.dart` then `lib/services/api_client.dart` |
| Screen behaviour or layout | `lib/screens/<name>.dart` + its provider |
| Displayed text (EN/FR) | `lib/utils/i18n.dart`, used as `t('key')` |
| Pricing / money formatting | `lib/utils/price_extension.dart`, `currency_helper.dart` |
| Plan / subscription gating | `plan_gate_logic.dart`, `providers/plan_provider.dart`, `middleware/planAuth.js` |
| Print / PDF / Excel export | `lib/services/receipt_printer.dart`, `lib/utils/*_report_files.dart` |
| App logo / brand asset | `assets/icons/icon.png`; the legal pages serve the same art as `drinks-calculator-backend/public/logo.png` — replace both together |
| Password reset limits (emails per day, wrong codes) | `drinks-calculator-backend/utils/passwordReset.js` + `utils/passwordResetStore.js`, table `password_reset_requests` |
| Feature history and phase status | `ROADMAP.md` (append only, never rewrite) |

## Never read (ignored on purpose — see `.clineignore`)
`build/`, `.dart_tool/`, `node_modules/`, `.git/`, `android/.gradle/`, `*.log`,
lockfiles. `.env*` and `drinks-calculator-backend/scripts/{live_smoke,debug_login,reset_test_pwd}.js`
contain live credentials — do not open, print or copy them.
