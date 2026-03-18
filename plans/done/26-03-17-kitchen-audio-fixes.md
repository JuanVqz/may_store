# Kitchen Queue Fixes

## Issues

### 1. No beep when adding items to a confirmed order
`Order#add_item!` creates a line item directly as `cooking`, but `broadcast_kitchen_update` only fires via `after_update_commit` (status change on update). `confirm!` manually calls `broadcast_kitchen_update` for each item, but `add_item!` doesn't — so the kitchen never sees/hears the new item via broadcast.

### 2. Waiter should hear beep when kitchen marks item "Listo"
Currently no audio feedback reaches the waiter's order view when an item becomes ready. Only the waiter viewing the specific order should hear it (scoped by `order_{id}` channel — already correct by design).

### 3. `opened_at` nil crash in kitchen card
`kitchen/_line_item_card.html.erb` calls `l(item.order.opened_at, format: :time_only)` but the column is nullable. Nil raises `I18n::ArgumentError` and breaks the kitchen page.

### 4. `oldest_cooking_id` never passed in broadcasts
`broadcast_kitchen_update` renders the card partial without the `oldest_cooking_id` local, so the "MÁS ANTIGUO" banner never appears on broadcasted cards — only on page refresh. Acceptable as best-effort.

### 5. Kitchen cancel targets wrong DOM id
`cancel.turbo_stream.erb` removes `line_item_{id}`, but kitchen uses `kitchen_line_item_{id}`. Broadcast handles it. **Won't fix.**

### 6. Queue count goes stale
`#kitchen-queue-count` only set on page load, no broadcast updates it.

### 7. Empty state not managed by broadcasts
"No items" message stays when items are appended; doesn't appear when last item is removed.

### 8. No status transition guards
Nothing prevents `mark_ready!` on a delivered item or double-clicks.

### 9. Takeouts page doesn't reflect status changes
`/takeouts` has no Turbo Stream subscription — fully static after page load.

### 10. Remove inaccurate "Esperando X min para recoger" text
Kitchen card shows `"LISTO - Esperando 65 min para recoger"` but the wait time is total item age, not time since marked ready. Redundant — order time already in meta line.

### 11. Waiter beep scoping
Already handled by design — order view subscribes to `order_{id}`, only the waiter viewing that order gets the broadcast. No extra work beyond #2.

### 12. Real-time "X de Y productos listos" on tables and takeouts
Waiters can't see item readiness progress without opening each order. Need progress line on `/tables` and `/takeouts` cards, updated on each line item status change.

### 13. "Marcar como entregado" from kitchen doesn't update order view
Broadcast code path looks correct but the order show view doesn't reflect the change. Likely race condition: `check_delivered!` transitions the order, triggering `broadcast_order_update` which re-renders items with stale in-memory data, overwriting the correct line item broadcast.

## Phase 1: Bug fixes (targeted, current broadcast approach)

Files touched: `line_item.rb`, `order.rb`, `kitchen/_line_item_card.html.erb`, `tables/_table.html.erb`, `takeouts/index.html.erb`, `line_items_controller.rb`, new `waiter_audio_controller.js`

### Step 1: Investigate & fix #13 — deliver not reaching order view
- [x] Add `order.line_items.reload` in `broadcast_order_update` before re-rendering items to fix stale data
- [x] Verify: kitchen marks delivered → order view updates

### Step 2: Fix #1 — add_item! kitchen broadcast
- [x] In `Order#add_item!`, call `item.broadcast_kitchen_update` after create (same pattern as `confirm!`)

### Step 3: Fix #3 — opened_at nil crash
- [x] In `kitchen/_line_item_card.html.erb`, fall back to `created_at` when `opened_at` is nil

### Step 4: Fix #10 — remove inaccurate ready wait time
- [x] Change the ready banner from `ready_pickup` (with minutes) to just "LISTO"

### Step 5: Fix #6 — kitchen queue count
- [x] Broadcast a replace for `#kitchen-queue-count` in `broadcast_kitchen_update`
- [x] Need count of cooking+ready items for the store — query in broadcast or pass from controller

### Step 6: Fix #7 — empty state management
- [x] Stimulus controller on `#kitchen-queue` that toggles `#kitchen-no-items` visibility based on children count
- [x] Listens for `turbo:before-stream-render` to re-evaluate after each stream action

### Step 7: Fix #9 — takeouts real-time updates
- [x] Add `turbo_stream_from "store_#{Current.store.id}_takeouts"` to takeouts view
- [x] Extract `takeouts/_order_card` partial from inline markup
- [x] Give each card a DOM id: `takeout_order_{id}`
- [x] Broadcast replace to `store_{id}_takeouts` channel from `Order#broadcast_order_update` when order's spot is takeout

### Step 8: Add #12 — "X de Y listos" on tables and takeouts
- [x] Add `Order#readiness_counts` → `{ ready: N, total: M }` (ready+delivered vs non-cancelled)
- [x] Add progress line to `tables/_table` partial: "X de Y listos"
- [x] Add progress line to `takeouts/_order_card` partial
- [x] Extend `LineItem#broadcast_item_update` to also broadcast table/takeout card on status change (not just on order status change)

### Step 9: Add #2 — waiter beep on "Listo"
- [x] Create `waiter_audio_controller.js` — listens for turbo stream replace events on `line_item_*`, checks if replaced content has ready status, plays beep (different tone: 600Hz vs kitchen 800Hz)
- [x] Attach `data-controller="waiter-audio"` to order show view items container

### Step 10: Fix #8 — status transition guards
- [x] `mark_ready!` → raise/return unless `cooking?`
- [x] `mark_delivered!` → raise/return unless `ready?`
- [x] `cancel!` → raise/return unless status in `[:ordering, :cooking, :ready]`

### Step 11: Tests
- [x] Test `Order#add_item!` broadcasts to kitchen
- [x] Test `Order#confirm!` broadcasts to kitchen
- [x] Test status transition guards reject invalid transitions
- [x] Test takeouts broadcast on order status change
- [x] Fix kitchen controller test `fixture_exists?` guard
- [x] Test `Order#readiness_counts`

## Phase 2: Refactor to Turbo Morph (separate plan)

Replace all manual `broadcast_replace_to`/`broadcast_append_to`/`broadcast_remove_to` with `broadcast_refreshes_to` + `turbo_refreshes_with method: :morph` on each page. This eliminates most of the broadcast complexity and auto-solves stale data, queue count, empty state, and progress updates. Separate plan once Phase 1 is stable.
