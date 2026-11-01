# Project brief — Drink Quick Cal

Drink Quick Cal is a drinks sales and stock management app for phones and tablets.
One customer of the app is one **company** — a bar, a restaurant, a shop or a
wholesaler — and a company may run several locations. It records what you sell,
keeps the stock right, follows customers who owe money, and closes the day's cash-up.
It works **offline**: if the network drops, keep selling, and the app synchronises
when the connection comes back.
The UI is bilingual (English / French) and prices render with the `Frs` symbol
(configurable in `CurrencyHelper`).

## What it does
1. Takes drink orders quickly — calculator-style entry, optional voice input, and
   barcode scanning.
2. Tracks inventory: stock levels, batches, production/expiry dates, movements.
3. Gives managers insight: revenue and peak-hour dashboards, popular items, and a
   demand forecast with recommended reorder quantities.
4. Produces customer-facing documents: invoice, PDF/Excel/CSV reports, and thermal
   (ESC/POS) receipts.
5. Gates paid features behind a subscription plan and enforces owner / manager /
   admin / staff roles.

## Users
Owners and managers (setup, analytics, staff), staff (fast order entry), on phone
and tablet. Android is the primary target; iOS, web, Windows, macOS and Linux
folders exist for the Flutter project.

## Where the plan lives
`ROADMAP.md` is the source of truth for features and phase status. Append to it;
never rewrite it. `DEPLOY.md` covers deployment (Render + Supabase).
