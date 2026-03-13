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

### Recommendation

**Use morphing for this refactor.** Reasons:

1. The single-page order view will have many interactive elements (accordions, form inputs, category tabs). Morphing preserves all of that state automatically.
2. A restaurant store has low concurrent connections (a handful of waiters + kitchen). The extra server load is negligible.
3. We can delete all custom broadcast methods, broadcast-specific partials, and target ID wiring. Much less code to maintain.
4. Adding new real-time elements (e.g. kitchen view later) requires zero broadcast setup — just `broadcasts_refreshes` on the model.

---

## Steps

### 1. Unified Order Page

- [ ] New `orders/show` layout: product browser on top, order summary on bottom
- [ ] Category tabs switch products via Turbo Frame (no full reload)
- [ ] Order summary section always visible, updated via Turbo Stream on item add/remove

### 2. Inline Customization

- [ ] Clicking [⚙] expands an accordion under the product card (Turbo Frame or Stimulus)
- [ ] Customization form submits via Turbo, collapses on success
- [ ] Products without customization use [+] button that adds directly via Turbo

### 3. Quick Add (No Customization)

- [ ] [+] button sends POST via Turbo Stream, item appears in order summary instantly
- [ ] No page navigation needed

### 4. Order Summary (Bottom Section)

- [ ] Shows line items with name, price, delete button (while OPEN)
- [ ] Running total updates live
- [ ] "Confirmar Orden" button transitions to active order view in-place

### 5. Active Order Mode

- [ ] After confirmation, product browser section hides or collapses
- [ ] Order items show status badges, mark ready/delivered buttons
- [ ] "Agregar Productos" re-expands the product browser
- [ ] Real-time updates via existing Turbo Streams broadcasts

### 6. Controller Refactor

- [ ] Merge `OrderProductsController` logic into `OrdersController#show`
- [ ] `LineItemsController#create` responds with Turbo Stream (append item to summary)
- [ ] `LineItemsController#new` renders inline partial (Turbo Frame) instead of full page
- [ ] Remove or deprecate standalone product browser / customization pages

### 7. Stimulus Controllers

- [ ] Accordion controller for inline customization expand/collapse
- [ ] Reuse existing `customization_controller` for portions/extras/price calc

### 8. Tests

- [ ] Update controller tests for new response formats (Turbo Stream)
- [ ] Test inline customization flow
- [ ] Test quick-add flow

---

## Done When

- Waiter can browse, customize, add items, and see order summary on one page
- No full-page navigations during the ordering flow
- Confirmation switches to active order view in-place
- All existing Turbo Streams broadcasts still work
- Tests pass
