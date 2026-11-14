# The download page — Cloudflare Workers (static assets)

This is the app's public front door: the page a shop opens to get the APK. It is a **static site
with no build step** — the files in `download-page/`, plus `wrangler.jsonc` at the repo root, which
is what `npx wrangler deploy` reads.

It used to be served by the backend (`drinks-calculator-backend/public/download.html`) from the
**free Render instance that spins down after ~15 minutes idle**. That is the wrong home for a front
door: measured on this project, the first request after a sleep answered **503**, then took ~100
seconds to warm up. A shop could meet a timeout before it met the app. A static host is always on.

## Deployed

| URL | What |
|---|---|
| `https://drink-quick-cal.mbundaderick.workers.dev` | **Live** (the page a shop opens) |
| `https://drink-quick-cal.mbundaderick.workers.dev/app-release.apk` | **Live** — the installation file, streamed from this domain |
| `…/privacy.html` · `/terms.html` · `/dpa.html` (+ `.fr`) | **Live** — the legal pages (a `.html` request gets a 307 to the extensionless path, which is Cloudflare's own canonicalisation) |
| a custom domain | **still to add** — Worker → Settings → Domains & Routes |

### The installation file is served from this domain, not from where it is kept

An 82 MB APK cannot sit in `download-page/`: Cloudflare's limit is **25 MiB per static asset** —
*"The individual file size limit of 25 MiB remains unchanged for all customers"* (Cloudflare
changelog). So the file is published elsewhere, and `cloudflare/download-page.js` — the Worker's only
code — streams it back out at **`/app-release.apk`**. A shop's URL bar and download list therefore
show this domain, never the host that keeps the file.

**That URL never changes between releases.** When a new APK is published, only `APK_UPSTREAM` in
`wrangler.jsonc` moves, plus the version/hash/notes on the backend — the address shops use stays the
same, so a link handed out once keeps working.

The route costs nothing to run: Cloudflare serves a static asset whenever one matches, so the script
is reached only for that single path (the page itself is still served as a free static asset). It is
deliberately **not** inside `download-page/` — everything in that directory becomes a public URL.

Checked against the live deployment, not just locally: `/` → **200** (`CF-Cache-Status: HIT`),
`/download` and `/download.html` → **301** to `/`, `/_headers` and `/_redirects` → **404** (they are
read, never served), `/logo.png` → 200 with `Cache-Control: public, max-age=604800`, and the CSP /
`X-Frame-Options` / nosniff / referrer-policy / permissions-policy headers all present. The French
text was verified on the live bytes (`Vérifier à nouveau`, `Confidentialité` — intact, no mojibake).

## The files

| File | Served publicly? | Why |
|---|---|---|
| `download-page/index.html` | yes — at `/` | The page. Bilingual by a `data-en` / `data-fr` swap, not two files. |
| `download-page/logo.png` | yes | The same art as `drinks-calculator-backend/public/logo.png` (**identical SHA-256**), kept here so the page needs no other host *to render*. This is now the **third** copy of that art (`assets/icons/icon.png`, the backend's, this one) — a brand change updates all three. |
| `download-page/_headers` | **no** — config | The security headers a static host does not send by default. |
| `download-page/_redirects` | **no** — config | Sends the old `/download.html` and a typed `/download` to `/`. |
| `download-page/privacy.html` · `terms.html` · `dpa.html` (+ `.fr`) | yes | The legal pages, moved here from the backend so a new shop reads the terms — before creating an account — without meeting a cold start. Byte-copied, wording untouched; the API host 302-redirects the old paths to these. |
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

The same deploy from a machine (`npx` fetches wrangler for that one command):

```powershell
npx wrangler deploy
```

## The build installs 177 backend packages for nothing (and how to stop it)

The first deploy's log showed Cloudflare running `npm clean-install` at the repo root, which fired
the root `package.json`'s `postinstall`:

```
> drinks-calculator-backend-root@1.0.0 postinstall
> npm --prefix drinks-calculator-backend install --omit=dev
added 177 packages in 4s
```

That root `package.json` is not ours to delete — it is the **Render shim** (`npm start` →
`node server.js`) — but the consequence is worth naming: **the download page's deploy depends on the
backend's dependency tree installing.** If a backend dependency ever fails to install, the front door
stops deploying, and nothing about that is visible from the outside. It is also ~10 s and a
dependency cache per build to upload four static files.

**The fix, documented by Cloudflare:** set the build variable **`SKIP_DEPENDENCY_INSTALL`** to `1`
(Worker → Settings → Environment variables). Automatic dependency installation is then skipped and
`npx wrangler deploy` runs on its own, fetching wrangler itself — which is all this site ever needed.
That is the difference between a front door that breaks when a payment library breaks and one that
does not.

(The other way to bake in the same decoupling: a Pages project whose **root directory** is
`download-page`, which contains no `package.json` at all.)

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
2. **The legal pages now live *here*, and the backend redirects to them** (see the file table). While
   the backend served them the rule was "linked, not copied" — and what that rule protects is *one
   copy*, which a redirect keeps: the text exists only in this folder and the old paths point at it.
   The wording was copied byte-for-byte, so it must not be edited here without bumping
   `LEGAL_VERSION` (that is what makes existing users re-accept a changed document).

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

