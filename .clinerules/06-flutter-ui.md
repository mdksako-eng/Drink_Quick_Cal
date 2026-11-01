---
paths:
  - "lib/screens/**"
  - "lib/widgets/**"
---

# Screen / widget rules

- Responsive layout is `sizer`-based; use the scaling helpers used by the sibling
  screen instead of inventing new `MediaQuery` maths.
- Read state through providers: `Provider.of<T>(context, listen: false)` for
  actions, `listen: true` for rebuilds. Screens never call Supabase/HTTP
  directly — everything goes through `lib/services/`.
- Every visible string comes from `t('key')`; new keys go into `_en` and `_fr`.
- Reuse `lib/widgets/` (`skeleton.dart`, `plan_gate.dart`, `offline_indicator.dart`,
  `drink_card.dart`, `custom_drawer.dart`, `invoice_widget.dart`) before writing a
  new widget.
- Drawer entries, role gates (owner/manager/admin/staff) and plan gates must stay
  consistent when a screen is added — mirror `custom_drawer.dart` and
  `utils/staff_permissions.dart`.
- `test/screens_layout_test.dart` pumps the heaviest screens at phone and tablet
  sizes with all providers injected and fails on any *layout* error. If you add a
  screen with new provider requirements, keep that harness green (`flutter test`).
