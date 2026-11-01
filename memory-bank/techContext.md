# Tech context

## App (`lib/`)
- Flutter, SDK `>=3.0.0 <4.0.0`; Material; package name `drinks_calculator_fixed`.
- State: `provider` — `ChangeNotifier` providers registered in `lib/main.dart`
  (`auth`, `drink`, `inventory`, `order`, `plan`, `sync`).
- Networking: `http` through `lib/services/api_client.dart` with URLs from
  `lib/config/api_config.dart`. `supabase_flutter` is used for auth/legacy REST.
- Local persistence: `shared_preferences` (offline cache, settings, events),
  `flutter_secure_storage` (secrets/session), `path_provider` (exports).
- Notable packages: `sizer`, `intl`, `pdf` + `printing`, `excel`, `csv`,
  `share_plus`, `open_file`, `image_picker`, `mobile_scanner`, `qr_flutter`,
  `print_bluetooth_thermal`, `flutter_tts`, `speech_to_text`,
  `flutter_local_notifications`, `connectivity_plus`, `local_auth`,
  `device_info_plus`, `crypto` + `encrypt`, `permission_handler`.
- Tests: 18 files in `test/` run by `flutter test`; lints via `flutter_lints`.
- Analyzer baseline (2026-09-23): `flutter analyze lib` → 0 errors, 50 warnings,
  431 infos (481 issues), exit code 1. Pre-existing; leave unrelated warnings alone.
- Build outputs are large (`build/` 1.3 GB, `.dart_tool/` 216 MB) and are filtered
  out of Cline's context by `.clineignore`.

## Backend (`drinks-calculator-backend/`)
- Node CommonJS, Express 5, Postgres through `pg` Pool (`DATABASE_URL`),
  helmet, express-validator, morgan, winston, socket.io, multer, pdfkit.
- Dependencies also list `cloudinary`, `@sendgrid/mail`, `nodemailer`,
  `jsonwebtoken`, `bcryptjs`, `mongoose` (Mongoose models exist under `models/`
  but the live data path is Postgres — see `systemPatterns.md`).
- Sessions are DB-backed (`middleware/sessionAuth.js`); plan checks in
  `middleware/planAuth.js`.
- Tests: Jest + supertest → `npm --prefix drinks-calculator-backend test`.
- Deployment: Render (`render.yaml`), `GET /health` reports the `RELEASE`
  constant near the top of `server.js` (currently `2026-09-20-phase8`).

## Environment notes
- Local Node: v24.11.1. Flutter stable installed.
- `.env` is local-only and git-ignored; `.env.example` documents required keys.
- This Windows PowerShell reads UTF-8 files as ANSI, so accented files
  (`lib/utils/i18n.dart`) must never be rewritten through a shell pipeline.
- Cline configuration in this repo: `.clineignore` (context filter),
  `.clinerules/` (always-on + path-scoped rules), `memory-bank/` (persistent
  memory). See `.clinerules/04-token-hygiene.md` before doing broad exploration.

## Cline configuration reality (2026-09-23)
- `.clineignore` may be inert: Cline 4.1.20 ships a `legacy` bundle (has ignore
  support) and a `next` bundle (has none); the launcher chooses via the setting
  `cline.sdkBundle` / `cline.rollout.bundleOverride` or `CLINE_BUNDLE_OVERRIDE`.
  A workspace search leaked `.dart_tool` hits, so assume no filtering.
- `build/` and `.dart_tool/` were removed from disk (both regenerable) so no tool
  walks them by accident. After a fresh clone, run `flutter pub get` first.
- VS Code level excludes live in `.vscode/settings.json`.

- Post-cleanup state (2026-09-23): `build/`, `.dart_tool/flutter_build` and
  `.dart_tool/chrome-device` were deleted; `.dart_tool` now holds 6 files.
  Repo files excluding `.git` went from 29,824 to 11,500, and 11,096 of those are
  `node_modules` (skipped by every tool by default). The first `flutter run` or
  `flutter build` afterwards is slower while caches regenerate.
