# MayStore - Project Documentation

**Version:** 5.0
**Last Updated:** March 2026

---

## Quick Reference

| File | Description |
|------|-------------|
| [models.md](./models.md) | ER diagram, all models, status flows |
| [wireframes.md](./wireframes.md) | UI mockups for all screens |
| [seeds.rb](./seeds.rb) | Database seed file with products |
| [locales.yml](./locales.yml) | Spanish locale file (default) |

---

## Tech Stack

| Technology | Version |
|------------|---------|
| Ruby | Latest |
| Ruby on Rails | 8.1 |
| Database | PostgreSQL |
| Authentication | Rails 8 built-in (`has_secure_password` on Account, `Current` for request state) |
| Frontend | Hotwire (Turbo + Stimulus) |
| Multitenancy | Subdomain-based |
| Money | Manual (prices in cents) |
| I18n | Rails built-in, default locale: `:es` |

---

## Changes from v4

### Critical Fixes

1. **Extras use add/remove counter** — same extra can be added multiple times (double extra chocolate = 2 LineItemComponent records). No unique index on `line_item_components(line_item_id, component_id)`. Portion is always 1.0 per record.
2. **Order code generation uses advisory lock** to prevent race conditions under concurrent inserts.
3. **Order status COOKING restored** — when waiter confirms, both the order AND all items go to COOKING. No ambiguous CONFIRMED status.
4. **Status checks use SQL queries** (`EXISTS`) instead of loading all items into Ruby memory.

### Architecture Changes

5. **Separated auth into Account model** — `Account` holds `employee_number`, `password_digest`, and `has_secure_password`. `User` holds profile info (name, role, email, phone). Supports waiter, kitchen, and admin roles.
6. **Unified Waiter/Kitchen/Admin into User with role** — `User` model with `role` enum (waiter, kitchen, admin).
7. **Renamed OrderItem -> LineItem, OrderItemComponent -> LineItemComponent** — shorter, industry-standard, unambiguous. `ProductComponent` stays (recipe definition).
8. **ComponentType table removed** — replaced with string enum `component_type` on `ProductComponent` and `LineItemComponent`.
9. **Soft delete added** — `deleted_at` column on User, Product, Component, Category. No gem, no `default_scope`. Use explicit scopes: `Product.active`, `User.active`.
10. **Removed `subtotal_cents`** from Order — only `total_cents` in MVP.
11. **Order-level cancellation added** — CANCELLED status on Order with `cancel!` method.
12. **Split payment support** — multiple Payment records per order.
13. **Cash Closing (Corte de Caja)** — admin feature for daily cash audit per payment method.
14. **Full I18n support** — all user-facing text from locale files. Default locale: `:es` (Spanish).
15. **`is_default` replaced with `required`** on ProductComponent — `required: true` means the ingredient cannot be set to portion 0 (it's a base component of the product).
16. **Ingredient UI: discrete buttons** — `(Sin) (1/4) (1/2) (3/4) [Normal]`. Required ingredients omit "Sin".
17. **Crepes restructured** — 4 specific products (Crepa de Nutella, etc.) instead of generic "Crepa 1/2 Ingredientes". Second filling via crepe-specific extras at $10 each.
18. **All roles can perform all item actions** — role determines default screen, not permissions.

---

## Key Design Decisions

### 1. Order Code Format

```
{STORE_PREFIX}{YY}{MM}-{SEQUENCE}

Examples:
CFE2601-001 -> Cafe Delicias, January 2026, order 1
MIA2602-001 -> Mi Cafe, February 2026, order 1
```

- Store-specific prefix (`order_prefix` on Store model)
- Monthly reset
- Atomic sequence via `OrderCounter` table (one row per store per month)

### 2. Status Flows

**Order Status:**
```
OPEN -> COOKING -> READY -> DELIVERED -> CLOSED
                                      \-> CANCELLED
```

**Item Status:**
```
ORDERING -> COOKING -> READY -> DELIVERED
                    \-> CANCELLED
```

### 3. Kitchen Workflow

```
1. Waiter builds order (OPEN)
   +-- Items: ORDERING

2. Waiter CONFIRMS order
   +-- Order: COOKING
   +-- ALL items: COOKING (automatic!)

3. Any role sees items in queue (oldest first)
   +-- Items already COOKING
   +-- NO "Start Cooking" button
   +-- Any role can: MARK READY, CANCEL, or DELIVER

4. Items individually become:
   |-- Item 1 -> READY
   |-- Item 2 -> CANCELLED
   +-- Item 3 -> READY

5. When ALL items READY or CANCELLED:
   +-- Order -> READY

6. Any role delivers items individually:
   |-- Item 1 -> DELIVERED
   +-- Item 3 -> DELIVERED

7. When ALL items DELIVERED or CANCELLED:
   +-- Order -> DELIVERED

8. Payment:
   +-- Order -> CLOSED
```

### 4. Adding Items After Confirm

The product browser is always visible on the order page (no "Agregar Productos" toggle). When a waiter adds items to a COOKING, READY, or DELIVERED order:
- New items go directly to COOKING (skip ORDERING)
- Order transitions back to COOKING (if it was READY or DELIVERED)
- Items appear in kitchen queue immediately

### 5. Authentication Model

```
Account (auth)          User (profile)
+-----------------+     +------------------+
| employee_number |     | name             |
| password_digest |---->| role (enum)      |
| user_id (FK)    |     | store_id (FK)    |
+-----------------+     | email, phone     |
                        | active           |
                        | deleted_at       |
                        +------------------+

Roles: waiter, kitchen, admin
```

- Login: find Account by employee_number (scoped to store via subdomain), authenticate password
- Redirect by role: waiter -> tables, kitchen -> queue, admin -> dashboard
- **Role = default screen, not permissions.** All roles can MARK READY, CANCEL, DELIVER items.
- Session: Rails 8 built-in session management

### 6. Price Storage (Cents, No Gem)

```ruby
module PriceCents
  extend ActiveSupport::Concern
  class_methods do
    def price_in_cents(*attributes)
      attributes.each do |attr|
        define_method(attr) { send("#{attr}_cents") / 100.0 }
        define_method("#{attr}=") { |d| send("#{attr}_cents=", (d.to_f * 100).round) }
        define_method("formatted_#{attr}") { "$#{'%.2f' % send(attr)}" }
      end
    end
  end
end
```

### 7. Portion vs Quantity

|             | Portion (how much)       | Quantity (how many)        |
|-------------|--------------------------|----------------------------|
| Ingredients | 0, 1/4, 1/2, 3/4, 1     | Always 1 (implicit)        |
| Extras      | Always 1.0 (implicit)    | 1, 2, 3... via `[- N +]`  |

**Ingredients:** Discrete buttons `(Sin) (1/4) (1/2) (3/4) [Normal]`. Default is Normal (1.0). Required ingredients omit the "Sin" button.

**Extras:** Add/remove counter `[-] [+]` with quantity indicator (`1x`, `2x`...). Each `[+]` creates one LineItemComponent record (portion always 1.0). Same extra can be added multiple times. No unique index.

### 8. Required Ingredients

`required` boolean on `ProductComponent`:
- `required: true` — ingredient cannot be set to portion 0. Buttons: `(1/4) (1/2) (3/4) [Normal]`
- `required: false` — ingredient can be removed. Buttons: `(Sin) (1/4) (1/2) (3/4) [Normal]`
- Extras always have `required: false`

Example (Chocomilk):
- Milk (required: true) — can reduce to 1/4, but always present
- Chocolate (required: true) — can reduce to 1/4, but always present
- Whipped Cream (required: false) — can be set to Sin

### 9. Crepe Products

Instead of generic "Crepa 1/2 Ingredientes" with selection logic, each filling is its own product:

| Product | Price | Required Ingredients |
|---------|-------|----------------------|
| Crepa de Nutella | $45 | Crepe Base, Nutella |
| Crepa de Cajeta | $45 | Crepe Base, Cajeta |
| Crepa de Lechera | $45 | Crepe Base, Lechera |
| Crepa de Rompope | $45 | Crepe Base, Rompope |

Second filling = add a crepe-specific extra:

| Extra | Price |
|-------|-------|
| Relleno Extra Nutella | $10 |
| Relleno Extra Cajeta | $10 |
| Relleno Extra Lechera | $10 |
| Relleno Extra Rompope | $10 |

"Crepa de Nutella + Relleno Extra Cajeta" = $45 + $10 = $55 (same as old "2 Ingredientes")

### 10. Soft Delete

```ruby
module SoftDeletable
  extend ActiveSupport::Concern
  included do
    scope :active, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
  end
  def soft_delete!
    update_columns(deleted_at: Time.current)
  end
  def restore!
    update_columns(deleted_at: nil)
  end
  def deleted?
    deleted_at.present?
  end
end
```

No `default_scope` — always use explicit scopes (`Product.active`, `User.active`).

Applied to: User, Product, Component, Category.

### 11. Cash Closing (Corte de Caja)

Daily cash audit performed by admin users. See models doc for details.

```
CashClosing
+-----------------+
| store_id (FK)   |
| user_id (FK)    |  <- admin who performed it
| closed_at       |
| period_start    |
| period_end      |
| status (enum)   |  <- open, closed
| notes           |
+-----------------+
       |
       | has_many
       v
CashClosingLine
+-----------------------+
| cash_closing_id (FK)  |
| payment_method_id(FK) |
| expected_cents        |  <- sum from orders
| actual_cents          |  <- admin-entered count
| difference_cents      |  <- actual - expected
+-----------------------+
```

### 12. I18n

- Default locale: `:es` (Spanish)
- All user-facing strings come from locale files
- Status labels, form labels, flash messages, button texts, etc.
- Set in `config/application.rb`:
  ```ruby
  config.i18n.default_locale = :es
  config.i18n.available_locales = [:es, :en]
  ```

---

## Model Names Reference

| Model | Table | Description |
|-------|-------|-------------|
| Store | stores | Tenant |
| Account | accounts | Auth credentials |
| User | users | Profile + role |
| Table | tables | Physical tables (name + position) |
| Category | categories | Product categories |
| Product | products | Menu items |
| Component | components | Ingredients and extras |
| ProductComponent | product_components | Recipe: which components a product has |
| Order | orders | Customer order |
| LineItem | line_items | Single item in an order |
| LineItemComponent | line_item_components | Component customization per line item |
| PaymentMethod | payment_methods | Accepted payment types |
| Payment | payments | Individual payment record |
| CashClosing | cash_closings | Daily cash audit |
| OrderCounter | order_counters | Monthly sequence per store |
| CashClosingLine | cash_closing_lines | Per-method audit line |

---

## Product Catalog

| Category | Products | Price Range |
|----------|----------|-------------|
| Bebidas Calientes | Espresso, Americano, Cappuccino, Latte | $25 - $60 |
| Tizanas | Durazno, Mango, Guayaba, Frutos Rojos | $50 |
| Crepas Dulces | Nutella, Cajeta, Lechera, Rompope | $45 (+$10 per extra filling) |
| Especialidades | Cucurumbe, Gloria | $99 |
| Frappes | Oreo, Mocha, Caramel | $70 - $75 |
| Postres | Fresas, Waffles | $55 - $75 |
| Extras | Helado, Fresas, Platano, Nuez | $10 - $20 |

---

## Development Phases

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1. Foundation | 1.5 weeks | Models, auth, seed data, I18n setup |
| 2. Order Process | 2 weeks | Waiter ordering flow |
| 3. Kitchen View | 1.5 weeks | Kitchen queue, status |
| 4. Bill & Admin | 1.5 weeks | Payment, cash closing, polish, deploy |

**Total: ~6.5 weeks**

---

## MVP Scope

### Included
- All models and migrations
- Authentication (Account + User with roles: waiter, kitchen, admin)
- Subdomain multitenancy
- Full I18n (Spanish default)
- Seed data for catalog
- Waiter views (login, tables, products, customization, orders)
- Kitchen views (login, queue oldest-first, status changes)
- Bill generation, split payment, and payment recording
- Order-level cancellation
- Soft delete on catalog entities
- Cash closing (corte de caja) for admin
- Real-time updates via Turbo Streams

### Not in MVP
- Admin CRUD for catalog (clone product feature noted for future)
- Reports and analytics beyond cash closing
- Offline mode
- Advanced print integration

---

## Local Development

### Accessing the app

MayStore uses subdomain-based multitenancy. Standard `localhost` does not support subdomains, so use `lvh.me` (which resolves to 127.0.0.1):

```
http://cafe.lvh.me:3000
```

The `cafe` subdomain matches the store created in `db/seeds.rb`. To start the app with Tailwind CSS watching:

```bash
bin/dev
```

This runs both the Rails server and the Tailwind watcher via `Procfile.dev`.

### Seeds

```bash
bin/rails db:seed
```

Creates a store with subdomain `cafe`, sample users (waiter, kitchen, admin), products, and components.

---

## Status: Ready for Development

All documentation finalized at **v5.0**. Ready to begin **Phase 1: Foundation**.

---

*MayStore - Streamlining order management*
