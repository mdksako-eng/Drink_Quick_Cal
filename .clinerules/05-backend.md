---
paths:
  - "drinks-calculator-backend/**"
---

# Backend rules (Express / Postgres)

- CommonJS only (`require`), Express 5, `pg` Pool. Follow the existing structure
  of `server.js`: section banner comments, small helper above the route.
- `server.js` is ~100 KB and 2000+ lines. Never read it whole — grep the route
  path or helper name, then read only that range (`start_line` / `end_line`).
- New pure logic belongs in `utils/` (e.g. `utils/staffPermissions.js`) with a
  matching Jest test in `tests/`, so the route stays thin and the rule testable.
- Auth: `requireSession` for user endpoints, `requirePlan` for paid features.
  Never trust a `company_id` or `role` sent by the client — resolve it from the
  session.
- Supabase tables sit behind RLS; the app never touches them directly, it calls
  this backend. Adding a table means adding its RLS script under `sql/` too.
- Secrets live only in `.env` (never commit, never print). `.env.example` is the
  documentation of record. `scripts/live_smoke.js`, `scripts/debug_login.js` and
  `scripts/reset_test_pwd.js` contain live credentials — do not open them.
- Passwords are bcrypt (`$2a$` / `$2b$` / `$2y$`); legacy plaintext rows upgrade
  on successful login. Do not add a second hashing path.
- After changing `server.js`: `node --check drinks-calculator-backend/server.js`
  then `npm --prefix drinks-calculator-backend test`.
