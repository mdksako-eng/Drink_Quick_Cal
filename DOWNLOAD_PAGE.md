# The download page — Cloudflare Workers (static assets)

This is the app's public front door: the page a shop opens to get the APK. It is a **static site
with no build step** — the files in `download-page/`, plus `wrangler.jsonc` at the repo root, which
is what `npx wrangler deploy` reads.

It used to be served by the backend (`drinks-calculator-backend/public/download.html`) from the
**free Render instance that spins down after ~15 minutes idle**. That is the wrong home for a front
door: measured on this project, the first request after a sleep answered **503**, then took ~100
seconds to warm up. A shop could meet a timeout before it met the app. A static host is always on.

## The files

| File | Served publicly? | Why |
|---|---|---|
| `download-page/index.html` | yes — at `/` | The page. Bilingual by a `data-en` / `data-fr` swap, not two files. |
| `download-page/logo.png` | yes | The same art as `drinks-calculator-backend/public/logo.png` (**identical SHA-256**), kept here so the page needs no other host *to render*. This is now the **third** copy of that art (`assets/icons/icon.png`, the backend's, this one) — a brand change updates all three. |
| `download-page/_headers` | **no** — config | The security headers a static host does not send by default. |
| `download-page/_redirects` | **no** — config | Sends the old `/download.html` and a typed `/download` to `/`. |
| `wrangler.jsonc` (repo root) | no | Where the assets are, and the Worker's name. |

**Nothing else belongs in `download-page/`.** Every file in that directory gets a public URL, which
is exactly why this runbook sits at the repo root instead of next to the page.

## Deploying — the dashboard fields

The Worker is connected to `mdksako-eng/Drink_Quick_Cal`:

| Field | Value | Why |
|---|---|---|
| Worker name | `drink-quick-cal` | Must match `name` in `wrangler.jsonc`, or wrangler creates a *second* Worker instead of updating this one. |
| Build command | **empty** | There is nothing to build; a command here could only fail or do nothing. |
| Deploy command | `npx wrangler deploy` | The default. It reads `wrangler.jsonc` and uploads `download-page/` as the Worker's assets. |
| Preview builds | optional | For a single static page, previews add little; leave them off unless you want per-branch URLs. |

There is deliberately **no `main`**: an assets-only Worker is valid, and with no script there is
nothing to run per request — the assets are served straight from Cloudflare's cache. `_headers` and
`_redirects` are **honoured** for Workers static assets (Cloudflare reads those two filenames and
does not serve them), so this site needs no Worker code at all.

The same deploy from a machine — no local install, no root `package.json`:

```powershell
npx wrangler deploy
```

Then set a **custom domain** (Worker → Settings → Domains & Routes) before sharing the URL with
shops: a `*.workers.dev` address is easy to mistype, and this is the address shops keep.

## The one thing to configure

The page reads its release metadata from the backend, because the version, the notes and the
SHA-256 live in the backend's environment — that stays the single source of truth, and this page
never invents a version. The page is static; the metadata is not. Exactly one line ties them
together:

```js
var API_BASE = 'https://drink-quick-cal-kja1.onrender.com';
```

**No backend change was needed for this move:** the release API already answers
`Access-Control-Allow-Origin: *`, verified against production with an `Origin` header rather than
inferred from `app.use(cors())`.

## Why the page has an "unreachable" state

The page loads instantly from Cloudflare, but the **version line needs the API**, which sits on a
free instance that sleeps. So the page can be up while its metadata is not, and those are two
different facts:

- API answers `known:false` → *"No build is published yet."* (the server's own words)
- API does not answer → *"Could not reach the download server just now. This page is fine — only the
  version check failed."*, with **Check again** and a link to the GitHub releases page

Two attempts (9 s timeout, one silent retry after 6 s), because a cold start usually answers on the
second. Before this, both failures rendered as *"No build is published yet."* — so a sleeping
instance read as a fact about the release.

**Testing it is the point:** leave the Render instance alone for 15+ minutes, then load the page.
You should get the page immediately, the version line after the first attempt or the retry, and the
fallback row only if it still cannot get through.

## The APK itself

Not hosted here, and never served by the backend either: it is ~82 MB, which belongs on **GitHub
Releases** (`APP_APK_URL` points there — see `RELEASE.md`). This page only links to it, so the
download bytes never touch Render.

## Two things left alone on purpose

1. **`drinks-calculator-backend/public/download.html` still works.** Two copies of a page drift, so
   the intended cleanup is a redirect on the next backend deploy — but swapping a live page for a
   redirect to a site that is not deployed yet is how a front door breaks.
2. **The legal pages are linked, not copied.** `privacy.html` / `terms.html` and their `.fr` twins
   are served by the backend and stay the single published copy of that text; the footer links to
   the language-matching one. Duplicating a legal document here would create a second copy that
   drifts.

## Two traps

- **Two files name the backend host:** `API_BASE` in `index.html`, and the CSP's `connect-src` in
  `_headers`. If the backend ever moves, a missed `connect-src` does not 404 — it blocks the fetch,
  so the page reports a perfectly healthy backend as unreachable. Change both together.
- **Never rewrite `index.html` through a shell pipeline.** It is UTF-8 with French accents
  (*Vérifier à nouveau*, *Confidentialité*) and PowerShell writes ANSI, which corrupts them. Use a
  file editor. Keep the `data-en` / `data-fr` pairs balanced: the swap reads them, and an element
  carrying only one silently falls back to English.

## If you would rather use Pages

Cloudflare Pages does the same job for this folder: connect the repo, **root directory
`download-page`**, no build command, build output `/`. It honours `_headers` and `_redirects` too,
and needs no `wrangler.jsonc`. Workers is what this project was set up with; the site is identical
either way.

