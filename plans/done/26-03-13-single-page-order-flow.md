# Refactor: Single-Page Order Flow

## Goal

Consolidate the multi-page ordering flow (product browser → customization page → order show) into a single screen where the waiter can browse products, customize, and see the order summary — all without leaving the page.

## Problem

Current flow requires 3+ full-page navigations to add a customized item and see the order. Too much back-and-forth for a fast-paced restaurant environment.

## Proposed UI

```
┌─────────────────────────────────────┐
│ ← Mesas          Mesa 5  [Abierto] │
├─────────────────────────────────────┤
│ [Bebidas Calientes] [Crepas Dulces] │  category tabs (Turbo Frame)
├─────────────────────────────────────┤
│ Americano              $35.00  [+] │  [+] = add directly (no custom)
│ Cappuccino Caramel     $45.00  [⚙] │  [⚙] = expand inline customization
│                                     │
│  ┌─ Inline Customization ─────────┐│
│  │ Espresso: (1/4)(1/2)(3/4)[Norm]││
│  │ Milk:  (Sin)(1/4)(1/2)(3/4)Norm││
│  │ Extras: Chocolate  [− 0 +]     ││
│  │ Notes: [___________]           ││
│  │          [Agregar $55.00]       ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│ Orden CFE2603-001        Total: $80│  always-visible order summary
│  Americano x1       $35.00   [🗑]  │
│  Cappuccino x1      $45.00   [🗑]  │
│                                     │
│        [Confirmar Orden]            │
└─────────────────────────────────────┘
```

After confirmation, same page switches to the active order view (status badges, mark ready/delivered buttons).

## Reference

- `docs/wireframes.md` — Screens 3-6
- `docs/turbo-streams.md` — Broadcast architecture
- https://turbo.hotwired.dev/handbook/page_refreshes#morphing

---

## Real-time Strategy: Morph vs Current Approach

### Current: Targeted Turbo Stream Broadcasts

Models broadcast specific partials to specific DOM targets via ActionCable.

```ruby
# Order model
after_update_commit :broadcast_order_update, if: :saved_change_to_status?

def broadcast_order_update
  broadcast_replace_to "order_#{id}", target: "order_#{id}", partial: "orders/order"
  broadcast_replace_to "store_#{store_id}_tables", target: "table_#{table_id}", partial: "tables/table"
end
```

| Aspect | Detail |
|--------|--------|
| **How it works** | Server renders a partial and pushes HTML over WebSocket. Client replaces the target element. |
| **Partials needed** | One per broadcast target (`_order`, `_line_item`, `_table`). Must be kept in sync with main views. |
| **Server load** | Low — only renders the small partial that changed. |
| **Precision** | High — only the changed element is replaced. |
| **Complexity** | High — each model needs custom broadcast methods, target IDs must match, partials must accept the right locals. |
| **State preservation** | Manual — replaced elements lose focus, open dropdowns, etc. |

### Alternative: Turbo Morph Refreshes

Models trigger a page refresh; Turbo uses idiomorph to diff the new HTML and only update changed DOM nodes.

```ruby
# Order model — replaces all custom broadcast methods
class Order < ApplicationRecord
  broadcasts_refreshes
end

class LineItem < ApplicationRecord
  broadcasts_refreshes
end
```

```erb
<%% # layout head %>
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

| Aspect | Detail |
|--------|--------|
| **How it works** | Server sends a "refresh" signal. Each connected client re-fetches the page. Turbo diffs old vs new DOM and patches only changed nodes. |
| **Partials needed** | None extra — views just render normally. |
| **Server load** | Higher — every connected client makes a full page request on each change. |
| **Precision** | Smart — idiomorph diffs the DOM tree, only touching changed nodes. |
| **Complexity** | Very low — one line per model, two meta tags. No target IDs, no broadcast partials. |
| **State preservation** | Automatic — scroll position, focus, form inputs, open accordions all preserved by morph. |

### Decision: Keep Targeted Broadcasts

**Stick with the current targeted Turbo Stream approach.** Morph can be adopted later per-page (via `<meta>` tags in specific views) without affecting the rest of the app, but for now the existing broadcast infrastructure works and is already tested.

See `plans/decisions/26-03-13-keep-targeted-broadcasts.md` for rationale.

---

## Steps

### 1. Controller & Route Prep

- [x] Add product listing logic to `OrdersController#show` (categories, products for selected category)
- [x] Make `LineItemsController#create` respond with Turbo Stream (append to summary + update total)
- [x] Make `LineItemsController#destroy` respond with Turbo Stream (remove from summary + update total)
- [x] Add route for inline customization: `LineItemsController#new` renders partial via fetch
- [x] Add `cancel` route + action for individual line items

### 2. Unified `orders/show` Page

- [x] Rebuild `orders/show` with two sections: product browser (top) + order summary (bottom)
- [x] Category tabs switch products via Turbo Frame (no full reload)
- [x] Product cards show [+] (quick add) and [⚙] (customize) buttons
- [x] Order summary always visible: line items, running total, delete buttons (while OPEN)
- [x] "Confirmar Orden" button at bottom
- [x] `orders#new` now redirects to `orders#show` instead of product browser

### 3. Inline Customization

- [x] [⚙] expands accordion under product card (`order-page` Stimulus controller)
- [x] Render customization form via fetch (`_customization_form.html.erb` partial)
- [x] Form submits via Turbo Stream — appends item to summary, collapses accordion
- [x] [+] quick-add sends POST via Turbo Stream — item appears in summary instantly
- [x] Reuse existing `customization_controller.js` for portions/extras/price calc

### 4. Active Order Mode

- [x] After confirm, product browser hides — order shows status badges + action buttons
- [x] Item actions: Listo, Marcar Entregado, Cancelar (based on item status)
- [x] "Agregar Productos" re-expands the product browser
- [x] Real-time updates via existing Turbo Stream broadcasts (updated to target `order_summary` + individual items)

### 5. Cleanup

- [x] Removed `OrderProductsController` and `order_products/index.html.erb`
- [x] Removed standalone `line_items/new.html.erb` full page
- [x] Removed unused `orders/_order.html.erb` partial (broadcast updated to target `_order_summary`)
- [x] Removed `order_products` route

### 6. Tests

- [x] Update controller tests for new redirect targets
- [x] Test Turbo Stream responses (create appends item + updates summary, destroy removes + updates summary)
- [x] Test inline customization endpoint (new returns partial with product + ingredient names)
- [x] Test cancel action for individual line items
- [x] Test unified show page: product browser visible for open, collapsed for cooking, category filtering
- [x] Test active order mode (cooking order shows Listo button)
- [x] Test adding item to ready order transitions it back to cooking
- [x] Test adding item to delivered order transitions it back to cooking

---

## Done When

- Waiter can browse, customize, add items, and see order summary on one page
- No full-page navigations during the ordering flow
- Confirmation switches to active order view in-place
- All existing Turbo Streams broadcasts still work
- Tests pass
