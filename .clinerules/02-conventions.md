# Conventions

## Dart / Flutter
- State lives in `ChangeNotifier` providers registered in `main.dart`. The
  dominant access style here is `Provider.of<T>(context, listen: ...)` (127 uses);
  `context.read` / `context.watch` are also used (25). Match the file you edit.
- Imports are mixed: `package:drinks_calculator_fixed/...` (182) and relative
  (170). Match the surrounding file; prefer relative paths inside `lib/`.
- User-visible text: never hardcode. Add the key to BOTH `_en` (i18n.dart:41) and
  `_fr` (i18n.dart:1052) and render it with `t('key')`. Both maps currently hold
  962 keys and parity must stay equal — `t()` falls back to the key itself, so a
  missing translation fails silently.
- User feedback: `Helpers.showToast(msg, isError: true)` (`lib/utils/helpers.dart`).
- Money: `value.formatted` from `price_extension.dart` (backed by
  `CurrencyHelper`), never manual symbol concatenation.
- Lints: plain `package:flutter_lints/flutter.yaml`, no custom rules. Keep
  `flutter analyze lib` at 0 errors.
- Web/desktop gaps: use the conditional-import factory pattern already used by
  `lib/services/tts/` and `lib/services/os_notifications/`.
- Tests: `test/<subject>_test.dart`. Put logic in `lib/utils/` so it is testable
  without pumping widgets.

## Vocabulary — one word per thing
The app is **not only bars**: a customer is a bar, a restaurant, a shop or a
wholesaler. Nothing in copy or code may assume what they sell or how they serve.
- **The customer, as an entity: "company" in EN, "entreprise" in FR.** It is
  already the product's word (62 EN strings, 31 FR) and the data model's
  (`companies`, `company_id` on every row). Never "bar", "shop", "establishment"
  or "business" as the noun for the customer's account.
- **A branch is a "location"** (`company_id` + location), never a "bar".
- **Products are "drinks" / "items"** — the catalogue is drinks (with a `Beer`
  category and a free-text `unit`: Bottle, Can, Crate…), so drinks examples are
  fine. A *quantity* is a "unit", sized per the invoice: 1 of 2 bottles and
  24 of 24 crates are the same code path.
- **A whole sale is normal**: the cart adds the same drink once per unit, so a
  crate sale is one line of 24. Never design a quantity control that assumes
  low numbers (see `widgets/return_items_dialog.dart`).
- The four legal pages (`drinks-calculator-backend/public/`) still define the
  customer as "Shop"/"Établissement" — a defined legal term, left as published;
  align it only as a deliberate, reviewed change.

## Hard rules
- NEVER rewrite `lib/utils/i18n.dart` through a shell pipeline (`Set-Content`,
  `-replace`, `>`). It is 2030 lines of UTF-8 French accents and PowerShell here
  writes ANSI, which corrupts them. Use the file editor only.
- Do not add a pub dependency without asking first.
- Do not reformat or re-indent code you were not asked to change.
