# Validation commands

Run the narrowest command that proves the change, then re-run the wider one once
at the end. Verified working on this machine (Node v24.11.1, Flutter stable).

| Purpose | Command |
|---|---|
| Dart/Flutter analysis (must stay 0 errors) | `flutter analyze lib` |
| Entire Flutter suite (18 test files) | `flutter test` |
| A single Flutter test | `flutter test test/analytics_export_test.dart` |
| Backend Jest suite | `npm --prefix drinks-calculator-backend test` |
| Backend syntax check (fast, no deps) | `node --check drinks-calculator-backend/server.js` |
| Run backend locally | `npm --prefix drinks-calculator-backend start` |

**Measured baseline (2026-09-23):** `flutter analyze lib` reports **0 errors**,
50 warnings and 431 infos (481 issues) and exits with code 1 in about 6 seconds.
That is pre-existing debt: do NOT clean up unrelated warnings inside another task,
and do not treat the non-zero exit code as a failure. The bar is simply *no new
`error -` line in the output*.

Flutter may print "A new version of Flutter is available" — unrelated to failures.

## EN/FR i18n parity check

Run from the repo root. Expected output: `EN=962 FR=962` and no differences.

```powershell
$f='lib/utils/i18n.dart'; $t=Get-Content $f -Raw
$en=[regex]::Match($t,'const Map<String, String> _en = \{(.*?)\n\};','Singleline').Groups[1].Value
$fr=[regex]::Match($t,'const Map<String, String> _fr = \{(.*?)\n\};','Singleline').Groups[1].Value
$ek=[regex]::Matches($en,"(?m)^\s*'([^']+)'\s*:") | ForEach-Object { $_.Groups[1].Value }
$fk=[regex]::Matches($fr,"(?m)^\s*'([^']+)'\s*:") | ForEach-Object { $_.Groups[1].Value }
"EN=$($ek.Count) FR=$($fk.Count)"
Compare-Object $ek $fk
```

## Terminal output hygiene

Always filter output: `Select-Object -First N`, `Select-String`, `-Name`,
`Measure-Object`. An unfiltered recursive listing of this repo emits ~30,000
lines; build output alone is 1.3 GB. When you only need the first few matches,
say so in the pipeline instead of reading everything.
