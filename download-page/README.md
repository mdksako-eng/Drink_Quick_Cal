# The download page (Cloudflare Pages)

This folder is the app's public front door — the page a shop opens to get the APK. It is a
**self-contained static site**: no build step, no server, no dependency.

It used to be served by the backend (`drinks-calculator-backend/public/download.html`) from the
**free Render instance that spins down after ~15 minutes idle**. That is the wrong home for a front
door: measured on this project, the first request after a sleep answered **503** and then took
~100 seconds to warm up, so a new shop could meet a timeout before seeing anything at all. A static
host is always on.

## Files

| File | Why |
|---|---|
| `index.html` | The page. Bilingual (EN/FR) by a `data-en` / `data-fr` swap, not two files. |
| `logo.png` | Copied from `drinks-calculator-backend/public/logo.png` — the same brand asset, kept here so the page needs no other host **to render**. It is now the **third** copy of that art (`assets/icons/icon.png`, `drinks-calculator-backend/public/logo.png`, and this one): a brand change updates all three together. |
| `_headers` | Cloudflare Pages picks this up automatically: the security headers a static host does not send by default. |

## The one thing to configure

`index.html` reads the release metadata from the backend, because the version, the notes and the
SHA-256 live in the backend's environment (that is the single source of truth — this page never
invents a version). The page is static; the metadata is not. Exactly one line ties them together:

```js
var API_BASE = 'https://drink-quick-cal-kja1.onrender.com';
```

Change that line if the backend ever moves. **No backend change is needed today:** the API already
answers with `Access-Control-Allow-Origin: *`, so this page can read it from a different origin
(verified against production, not assumed from reading the code).

## Deploying

**Option A — GitHub integration (recommended, redeploys on every push):**

1. Cloudflare dashboard → Workers & Pages → Create → Pages → Connect to Git.
2. Pick `mdksako-eng/Drink_Quick_Cal`.
3. **Root directory: `download-page`** · Build command: *(leave empty — there is nothing to build)*
   · Build output directory: `/`.
4. Deploy. The site lands on `https://<project>.pages.dev`.

**Option B — from this machine (no repo integration, nothing added to `package.json`):**

```powershell
npx wrangler pages deploy download-page --project-name drink-quick-cal-download
```

`npx` fetches wrangler for that one command; it is not a dependency of this repo.

A custom domain (for example `download.drinkquickcal.com`) is set in the Pages project under
**Custom domains** — worth doing before the URL is shared with shops, since a `pages.dev` address
is easy to mistype.

## Why the page has an "unreachable" state

The page loads instantly from the CDN, but the **version line needs the API**, which sits on a free
instance that sleeps. So the page can be up while its metadata is not. Those are two different
facts and the page keeps them apart:

- The API answers `known:false` → *"No build is published yet."* (the server's own words)
- The API does not answer at all → *"Could not reach the download server just now. This page is
  fine — only the version check failed."*, plus **Check again** and a link to the GitHub releases
  page.

Measuring that on purpose is how you test it: leave the instance alone for 15+ minutes, then load
the page. You should get the page immediately, the release line after the first attempt or the
single silent retry (a cold start often answers on the second), and the fallback row if it still
cannot get through.

## The APK itself

The APK is **not** hosted here and must never be served by the backend either: it is ~82 MB, which
belongs on **GitHub Releases** (`APP_APK_URL` points there — see `RELEASE.md`). This page only
links to it, so the download bytes never touch Render.

## Two things to know

1. **`drinks-calculator-backend/public/download.html` still exists** and still works. Two copies of
   a page drift, so once this site is live the intended cleanup is to replace that file with a
   redirect to the Pages URL (or delete it) on the next backend deploy. That was left untouched
   deliberately: swapping a working page for a redirect to a site that is not live yet is how you
   get a broken front door.
2. **The legal pages are linked, not copied.** `privacy.html` / `terms.html` (and their `.fr`
   twins) are served by the backend and remain the single published copy of that text; this page
   links to the language-matching one. Duplicating a legal document here would create a second
   copy that drifts.

## Editing it

Never rewrite `index.html` through a shell pipeline: it is UTF-8 with French accents
(*Vérifier à nouveau*, *Confidentialité*), and PowerShell writes ANSI, which corrupts them. Use a
file editor. Keep the `data-en` / `data-fr` pairs balanced — the language swap reads them, and an
element with only one of the two silently falls back to English.
