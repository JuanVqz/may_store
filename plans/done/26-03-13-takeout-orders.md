# Takeout Orders (Para Llevar)

## Goal

Support orders that don't require a table assignment (takeout / para llevar) by introducing a unified `Spot` model that replaces `Table`.

## Approach

Rename `Table` → `Spot` with a `spot_type` string enum (`dine_in` / `takeout`). Every order always `belongs_to :spot`. Dine-in orders point to a table spot, takeout orders point to the store's single takeout spot (auto-created via `find_or_create_by!`). Add a `/home` waiter landing page with two buttons: Mesas and Para Llevar.

**Future-proof:** New spot types (didi, uber, rappi) can be added as enum values — no schema changes needed, just new UI.

## Key Decisions

- **No `customer_name`** — order code is enough to identify takeout orders
- **No `order_type` on Order** — the spot's `spot_type` carries this info
- **`spot_id` is always required** — no nullable FK, no null-sniffing
- **One takeout spot per store** — auto-created via `Spot.takeout_for(store)`, name from i18n
- **Rollback & edit existing migration** — not in production, so rename at the source

## Steps

### Step 1: Rename Table → Spot (model, migration, DB)
- [x] Rollback all migrations (`rails db:rollback` to before tables migration)
- [x] Rename migration file: create `spots` table instead of `tables`
- [x] Add `spot_type` string column (default: `"table"`, null: false)
- [x] Update orders migration: `table_id` → `spot_id`
- [x] Delete `app/models/table.rb`, create `app/models/spot.rb`
- [x] Update `Store` model: `has_many :tables` → `has_many :spots`
- [x] Update `Order` model: `belongs_to :table` → `belongs_to :spot`
- [x] Re-run migrations (`rails db:migrate`)

### Step 2: Update controllers
- [x] Rename `TablesController` → keep name but query `Spot.tables` instead of `Table`
- [x] Update `OrdersController`: `table` references → `spot`
- [x] Create `HomeController` with `index` action (waiter landing at `/`)
- [x] Create `TakeoutsController` with `index` action (list takeout orders)
- [x] Update `SessionsController` redirect: waiter → `root_path` instead of `tables_path`

### Step 3: Update routes
- [x] Change `root` to `"home#index"` (authenticated waiter landing)
- [x] Add `resources :takeouts, only: [:index]`
- [x] Change order creation to `resources :spots, only: [] do; resources :orders, only: [:create]; end`
- [x] Keep `resources :tables, only: [:index]` for the table grid view
- [x] Remove old `tables/:id/orders` nesting

### Step 4: Update views
- [x] Update `tables/index.html.erb` — use `@spots` instead of `@tables`
- [x] Update `tables/_table.html.erb` partial — reference spot
- [x] Update `orders/_order_header.html.erb` — `order.table` → `order.spot`
- [x] Update `layouts/application.html.erb` if referencing tables
- [x] Create `home/index.html.erb` — two square buttons (Mesas / Para Llevar)
- [x] Create `takeouts/index.html.erb` — list of takeout orders + "Nueva Orden" button

### Step 5: Update locales
- [x] Add `spot_types.table` and `spot_types.takeout` to `es.yml`
- [x] Add home page translations
- [x] Add takeout page translations

### Step 6: Update tests & fixtures
- [x] Rename `test/models/table_test.rb` → `test/models/spot_test.rb`
- [x] Update `test/fixtures/orders.yml` — `table` → `spot`
- [x] Create `test/fixtures/spots.yml` (was `tables.yml`)
- [x] Update `test/controllers/tables_controller_test.rb`
- [x] Update `test/controllers/orders_controller_test.rb`
- [x] Add tests for `Spot.takeout_for(store)`
- [x] Add tests for `HomeController`
- [x] Add tests for `TakeoutsController`

### Step 7: Update seeds
- [x] Change table seed creation to use `Spot.create!` with `spot_type: :dine_in`
- [x] Add one takeout spot per store
- [x] Add sample takeout orders
- [x] Update existing order seeds to use `spot:` instead of `table:`

### Step 8: Update docs
- [x] Update `docs/models.md` — Table → Spot, add spot_type, ER diagram
- [x] Update `docs/wireframes.md` — add home screen, takeout screen
