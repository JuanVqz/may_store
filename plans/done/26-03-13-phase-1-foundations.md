# Phase 1: Foundations

## Goal
Set up all models, migrations, concerns, authentication, multitenancy, I18n, and seed data. No views/controllers beyond auth.

## Reference
- `docs/models.md` — All models, relationships, code examples
- `docs/seeds.rb` — Seed data
- `docs/locales.yml` — Spanish locale

---

## Steps

### 1. Database & Core Config
- [x] Configure PostgreSQL in `database.yml` — already configured by Rails generator
- [x] Enable UUID support — PostgreSQL 13+ has `gen_random_uuid()` natively, will add `pgcrypto` extension in Order migration as fallback
- [x] Set default locale to `:es` in `config/application.rb`
- [x] Set available locales `[:es, :en]`
- [x] Set timezone to `America/Mexico_City`
- [x] Uncommented `bcrypt` gem for `has_secure_password`
- [ ] Configure subdomain routing — deferred to Step 6 (auth), needs controller setup

### 2. Concerns
- [x] `PriceCents` — `price_in_cents` class method for dollar/cents helpers
- [x] `SoftDeletable` — `active`/`deleted` scopes, `soft_delete!`/`restore!`/`deleted?`

### 3. Models & Migrations (in dependency order)
- [x] `Store` — name, subdomain, order_prefix, logo_url, active
- [x] `User` — store_id, name, role (enum: waiter/kitchen/admin), email, phone, active, deleted_at
- [x] `Account` — user_id (unique), employee_number, password_digest, `has_secure_password`
- [x] `Table` — store_id, name, position, active
- [x] `Category` — store_id, name, description, icon, position, active, deleted_at
- [x] `Component` — store_id, name, description, price_cents, available, deleted_at
- [x] `Product` — store_id, category_id, name, description, base_price_cents, image_url, available, allows_customization, deleted_at
- [x] `ProductComponent` — product_id, component_id, component_type (enum: ingredient/extra), required, position
- [x] `Order` — UUID PK, store_id, table_id, user_id, status (enum), code, total_cents, notes, timestamp columns
- [x] `OrderCounter` — store_id, year_month, current_sequence
- [x] `LineItem` — order_id (uuid FK), product_id, status (enum), special_notes, base_price_cents, total_price_cents
- [x] `LineItemComponent` — line_item_id, component_id, component_type (enum), portion (decimal), unit_price_cents
- [x] `PaymentMethod` — store_id, name, description, active
- [x] `Payment` — order_id (uuid FK), payment_method_id, amount_cents, notes, paid_at
- [x] `CashClosing` — store_id, user_id, status (enum), period_start, period_end, notes, closed_at
- [x] `CashClosingLine` — cash_closing_id, payment_method_id, expected_cents, actual_cents, difference_cents

### 4. Indexes
- [x] Add all indexes from spec — included in migrations
- [x] Unique indexes all in place
- [x] NO unique index on line_item_components(line_item_id, component_id) — confirmed

### 5. Model Logic
- [x] All associations (`belongs_to`, `has_many`, `dependent`, `through`)
- [x] All enums (string-backed)
- [x] All validations
- [x] All `normalizes` declarations
- [x] `Current` model (store, user attributes)
- [x] `Order` — `generate_code`, `confirm!`, `check_ready!`, `check_delivered!`, `close!`, `cancel!`, `add_item!`, `recalculate_total!`
- [x] `LineItem` — `calculate_total!`, `mark_ready!`, `mark_delivered!`, `cancel!`, callbacks for order status/total
- [x] `CashClosing` — `calculate_expected!`, `close!`
- [x] `CashClosingLine` — `calculate_difference` before_save
- [x] Status colors and labels on Order/LineItem

### 6. Authentication Setup
- [x] `has_secure_password` on Account (done in Step 3)
- [x] `SessionsController` — login/logout
- [x] `ApplicationController` — `set_current_store` (subdomain), `set_current_user` (session)
- [x] `require_authentication` before_action
- [x] Redirect by role after login
- [x] Routes: login/logout, placeholder role landing pages

### 7. I18n
- [x] Copied locale to `config/locales/es.yml`
- [x] Verified keys align with controllers (login.error, login.logged_out, flash.store_not_found)
- [x] Removed `docs/locales.yml` (now at Rails location)

### 8. Seeds
- [x] Copied seeds to `db/seeds.rb`
- [x] Seeds run cleanly — 6 users, 15 tables, 23 products, 47 components, sample order CFE2603-001
- [x] Removed `docs/seeds.rb` (now at Rails location)

### 9. Tests
- [x] Fixtures for all 16 models (2 stores, 4 users, 2 tables, 2 categories, 4 components, 2 products, etc.)
- [x] Model tests: validations, enums, scopes (Store, User, Component)
- [x] `Order` tests: code generation, status transitions, `confirm!`, `cancel!`, `close!`, `add_item!`, `recalculate_total!`, payment tracking
- [x] `LineItem` tests: `calculate_total!`, status callbacks, order total recalculation
- [x] `LineItemComponent` tests: portion validation, duplicate extras, portion_label
- [x] `Account` tests: authentication, employee_number uniqueness per store
- [x] `SoftDeletable` tests (via User and Component)
- [x] `PriceCents` tests (via Component, LineItem, Order)
- [x] `CashClosingLine` difference calculation
- [x] 42 tests, 0 failures

---

## Done When
- `rails db:migrate` runs cleanly
- `rails db:seed` populates dev data
- `rails test` passes all model tests
- Login/logout works via subdomain
- `Current.store` and `Current.user` set correctly per request
