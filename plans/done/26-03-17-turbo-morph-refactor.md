# Turbo Morph Refactor

## Overview

Replace all manual Turbo Stream broadcasts (`broadcast_replace_to`, `broadcast_append_to`, `broadcast_remove_to`) with `broadcast_refresh_to` + `turbo_refreshes_with method: :morph` on each page. Morph diffs new HTML against the current DOM — no more hand-crafted broadcast partials or stale data bugs.

## Views

Each page gets `turbo_refreshes_with method: :morph, scroll: :preserve` and a stream subscription:

| View | Stream | Subscription status |
|------|--------|-------------------|
| `/kitchen` | `store_{id}_kitchen` | Already has it |
| `/tables` | `store_{id}_tables` | Already has it |
| `/takeouts` | `store_{id}_takeouts` | Already has it |
| `/orders/{id}` | `order_{id}` | Already has it |

## Models

### LineItem

Replace `broadcast_item_update`, `broadcast_kitchen_update`, `broadcast_kitchen_queue_count`, `broadcast_spot_update` with:

```ruby
after_update_commit :broadcast_refreshes, if: :saved_change_to_status?

def broadcast_refreshes
  broadcast_refresh_to "order_#{order_id}"
  broadcast_refresh_to "store_#{order.store_id}_kitchen"
  broadcast_refresh_to "store_#{order.store_id}_tables"
  broadcast_refresh_to "store_#{order.store_id}_takeouts"
end
```

### Order

Replace `broadcast_order_update` with:

```ruby
after_update_commit :broadcast_refreshes, if: :saved_change_to_status?

def broadcast_refreshes
  broadcast_refresh_to "order_#{id}"
  broadcast_refresh_to "store_#{store_id}_tables"
  broadcast_refresh_to "store_#{store_id}_takeouts"
end
```

### Order#confirm! and Order#add_item!

Replace manual `broadcast_kitchen_update` calls with `broadcast_refresh_to "store_#{store_id}_kitchen"`.

## What gets deleted

- `LineItem#broadcast_item_update` (private method)
- `LineItem#broadcast_kitchen_update` (public method)
- `LineItem#broadcast_kitchen_queue_count` (public method)
- `LineItem#broadcast_spot_update` (private method)
- `Order#broadcast_order_update` (private method)
- `kitchen_audio_controller.js` — deferred to backlog plan
- `waiter_audio_controller.js` — deferred to backlog plan
- `kitchen_queue_controller.js` — morph handles empty state naturally
- `data-controller="kitchen-audio kitchen-queue"` from kitchen view
- `data-controller="waiter-audio"` from order show view

## Morph requirements

Every element morph should track needs a stable `id`. Already in place:
- `kitchen_line_item_{id}`, `line_item_{id}`, `spot_{id}`, `takeout_order_{id}`
- `order_header`, `order_summary`, `kitchen-queue-count`

## Steps

### Step 1: Add morph to all 4 views
- [x] Add `<%= turbo_refreshes_with method: :morph, scroll: :preserve %>` to kitchen/index, tables/index, takeouts/index, orders/show

### Step 2: Refactor LineItem broadcasts
- [x] Replace `after_update_commit :broadcast_item_update` with `after_update_commit :broadcast_refreshes`
- [x] Write new `broadcast_refreshes` method
- [x] Delete `broadcast_item_update`, `broadcast_kitchen_update`, `broadcast_kitchen_queue_count`, `broadcast_spot_update`

### Step 3: Refactor Order broadcasts
- [x] Replace `after_update_commit :broadcast_order_update` with `after_update_commit :broadcast_refreshes`
- [x] Write new `broadcast_refreshes` method
- [x] Delete `broadcast_order_update`

### Step 4: Update confirm! and add_item!
- [x] Replace `item.broadcast_kitchen_update` calls with `broadcast_refresh_to "store_#{store_id}_kitchen"`

### Step 5: Remove audio controllers
- [x] Delete `kitchen_audio_controller.js`, `waiter_audio_controller.js`, `kitchen_queue_controller.js`
- [x] Remove `data-controller` references from kitchen and order views

### Step 6: Verify and test
- [x] Run existing test suite
- [x] Verify morph works in browser: kitchen, tables, takeouts, order views all update in real-time
