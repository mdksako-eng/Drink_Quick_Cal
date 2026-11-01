# Token discipline (apply on every task)

Goal: keep the context window small. Every tool result is re-sent on each
following request, so an oversized read is paid for many times over.

## Reading
- Search first, read second: use `search_codebase` (regex) before opening files.
- Never read from `build/`, `.dart_tool/`, `node_modules/`, `.git/`, `*.log` —
  they are ignored for exactly this reason. Ask the user instead of bulk-reading.
- Files over ~300 lines: read a line range around the match, never the whole
  file. `drinks-calculator-backend/server.js` (~100 KB) and
  `lib/utils/i18n.dart` are the usual offenders.
- Do not re-read a file after editing it to "verify". Report the change instead.

## Tool calls
- Batch independent reads / searches / commands into ONE response. Never issue
  a single trivial call per turn.
- Prefer one grep that answers several questions over several separate greps.
- Terminal output: always filter (`Select-Object -First N`, `Select-String`,
  `-Name`, `Measure-Object`). Never dump a whole log or directory tree.
- Prefer command output as evidence (`flutter analyze lib`, tests) over reading
  source files "to be sure".

## Editing
- Touch only the files named in the task. If more files are needed, list them
  and ask before editing.
- Surgical edits (`editor` with a small `old_text`), not whole-file rewrites.
- Do not restate the request or existing code in the reply. A few lines saying
  what changed and what was verified is enough.

## Task hygiene
- One feature per task. When the topic changes, tell the user to start a new
  task (`/newtask`) rather than continuing a long conversation.
- Use subagents for broad "where is X / how does Y work" exploration instead of
  reading many files inside the main task.
- Never paste whole logs or file contents into the chat — quote the failing
  lines only.

## Cline 4.1.20 reality check (measured 2026-09-23)

`.clineignore` is NOT reliably enforced on this install. Cline 4.1.20 ships two
bundles: `legacy/dist/extension.js` (contains `ClineIgnoreController` and
`validateAccess`) and `next/dist/extension.js` (contains no ignore logic at all).
The launcher picks between them via the `cline.sdkBundle` /
`cline.rollout.bundleOverride` settings and the `CLINE_BUNDLE_OVERRIDE` env var.
Observed in this workspace: a codebase search returned hits inside `.dart_tool`,
which `.clineignore` excludes, so assume no filtering is applied.

Therefore: treat `.clineignore` as best-effort, follow the rules in this file, and
rely on physical absence. `build/` and `.dart_tool/` were deleted on 2026-09-23 and
regenerate with `flutter pub get` plus a build. If they reappear, do not walk them.

- Post-cleanup 2026-09-23: `build/` plus the `flutter_build` and `chrome-device`
  caches are gone; `.dart_tool` holds 6 files. The first build regenerates them,
  which is expected and not a problem to fix.
