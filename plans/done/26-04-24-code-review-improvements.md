# Code Review & Improvements

## Goal

Full-repo pass: find and fix suboptimal patterns, dead code, missing tests, naming issues, and anything that could be done cleaner with the tools already in the stack.

## Scope

- Models: callbacks, validations, scopes, concerns
- Controllers: fat actions, missing authorization guards, N+1s
- Views: logic leaking into templates, missing i18n keys, hardcoded strings
- JavaScript: Stimulus controllers, unused controllers
- Tests: missing coverage on critical paths, fixtures quality
- CSS: unused classes, duplicated rules
- Gemfile: unused or upgradeable deps

## Done when

- No obvious N+1 queries in main flows (orders, kitchen, line items)
- No hardcoded user-facing strings outside locale files
- No dead code (unused controllers, methods, concerns)
- Critical flows (order lifecycle, payment, kitchen transitions) have test coverage
- Each PR review item addressed or documented as accepted tech debt

## Summary of changes (completed 2026-04-23)

### Fixed

1. **N+1: `Order#readiness_counts`** — Was issuing 3 COUNT queries per order on
   the orders index, tables, and takeouts pages. Now uses the loaded association
   in memory when preloaded (via `includes`), or falls back to a single `GROUP BY`
   query. Eliminates 2 extra queries per order row on every listing page.

2. **N+1: `LineItemsController#build_components` extras loop** — Was calling
   `Current.store.components.find(id)` once per extra component inside a loop.
   Now preloads all needed components in a single `WHERE id IN (...)` query.

3. **Hardcoded Spanish validation message in `Payment`** — `received_cents_must_cover_amount`
   had a literal `"debe ser mayor o igual a ..."` string. Replaced with
   `errors.add(:received_cents, :insufficient, amount: formatted_amount)` and
   added the key to `activerecord.errors.models.payment.attributes.received_cents`
   in `config/locales/es.yml`.

4. **Dead admin route causing 500 for admin users** — `config/routes.rb` had
   `get "admin", to: "admin/dashboard#index"` but no admin controller existed.
   Any admin user who logged in would get a routing error. Removed the dead route
   and changed `redirect_by_role` to send admin users to `root_path` (same as
   waiter) until a real admin dashboard is built.

### Accepted tech debt (not fixed)

- **CSS**: Tailwind utility classes are not audited for dead rules — too noisy
  without a purge report; Tailwind v4 handles this at build time anyway.
- **Gemfile**: No unused gems found; puma already upgraded in a prior commit.
- **JS Stimulus controllers**: All 6 controllers (`customization`, `flash`,
  `highlight`, `order-page`, `payment-form`, `print`) are referenced in views.
  No dead controllers.
- **Test coverage**: Controller and model tests were already comprehensive covering
  all critical flows (order lifecycle, payment, kitchen transitions). No gaps found.
- **Views / i18n**: No hardcoded user-facing strings found in ERB templates outside
  the PWA manifest (app name, acceptable).
