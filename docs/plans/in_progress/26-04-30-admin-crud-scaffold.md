# Admin CRUD Scaffold

Build store management UI for catalog and config models. All resources scoped by `Current.store`, Spanish-first, Hotwire-driven. Open to all authenticated users for now (no role gate).

## Scope

Admin CRUD for these models (in priority order):

1. **Categories** — `name`, soft-delete (no reorder UI yet)
2. **Components** (ingredients/extras) — `name`, `price_cents`, `available`, soft-delete
3. **Products** — `name`, `base_price_cents`, `category`, `available`, components (via `product_components`), soft-delete (no image upload yet)
4. **Spots** — `name`, `spot_type` (dine_in/takeout), `active` (no reorder UI yet)
5. **Payment methods** — `name`, `active`

Out of scope: users, orders, line items, cash closings, store settings, product images, drag-drop/integer reorder for categories and spots (revisit later).

## Routes

Namespace under `/admin`. Restrict to `admin` role via `before_action` in `Admin::BaseController`.

```ruby
namespace :admin do
  resources :categories
  resources :components
  resources :products
  resources :spots
  resources :payment_methods
end
```

## Controllers

- `Admin::BaseController < ApplicationController` — requires authenticated user only (no role gate for now), sets `Current.store` scope helpers.
- One controller per resource. Standard 7 actions (`index`, `new`, `create`, `edit`, `update`, `destroy`). `show` only where useful (products with components breakdown).
- All queries scoped via `Current.store.<assoc>`.
- `destroy` uses soft-delete (`SoftDeletable`) where applicable.

## Views

- ERB + Hotwire. Turbo Frames for inline edit on list rows where natural (categories, payment_methods).
- Forms: shared `_form.html.erb` per resource.
- Index: table with name + actions (edit, delete). Filter by `available`/`active` where present.
- Product form: nested `product_components` via `accepts_nested_attributes_for` + Stimulus controller for add/remove rows.
- All labels from `config/locales/es.yml` under `admin.<resource>.*`.

## Model changes

- `Product` — add `accepts_nested_attributes_for :product_components, allow_destroy: true`.
- `PaymentMethod` — confirm `active` boolean exists; add scope `ordered` if needed.

## Navigation

Add `Admin` link to header nav for all authenticated users. Sidebar inside `/admin` lists all resources.

## Tests

Minitest controller tests per resource: index/create/update/destroy happy path + scope leak check (cannot access other store's records). Model tests already exist for validations.

## Locales

Add `es.yml` keys:
- `admin.nav.*` (categories, components, products, spots, payment_methods, users)
- `admin.<resource>.index.title`, `.new.title`, `.edit.title`
- `admin.<resource>.attributes.*`
- Reuse `helpers.submit.*`, `helpers.label.*` where possible.

## Steps

- [x] `Admin::BaseController` (auth only) + admin layout
- [x] Categories CRUD + tests + locales
- [x] Components CRUD + tests + locales
- [x] Products CRUD (with nested components) + tests + locales
- [x] Spots CRUD + tests + locales
- [x] Payment methods CRUD + tests + locales
- [x] Header nav link + admin sidebar
- [ ] Manual QA pass on dev server — PR #65 open

## Deferred (revisit)

- Role gate on `/admin`
- Reorder UI for categories and spots (drag-drop or integer)
- User CRUD
- Product image upload
