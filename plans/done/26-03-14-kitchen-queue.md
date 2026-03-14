# Kitchen Queue Plan

## Overview

Real-time kitchen display showing individual line item cards sorted oldest-first. Kitchen staff marks items ready or cancelled. Uses the existing application layout (same navbar) and existing `LineItemsController` action endpoints. No prices shown.

## Decisions

- **No separate layout** — reuse `application.html.erb` as-is (navbar has brand + welcome + logout)
- **No namespaced controllers** — `KitchenController#index` for the view, existing `LineItemsController#ready`, `#cancel`, `#deliver` for actions
- **Individual cards, not grouped by order** — one task, one action, easier for hands-busy staff
- **Audio alert** via Web Audio API beep (no sound file needed)
- **Track who performed actions** — `ready_by_id`, `cancelled_by_id`, `delivered_by_id` on `line_items`
- **Stay until delivered** — items remain in kitchen queue through READY status, removed only on DELIVERED or CANCELLED

## Route

Already stubbed: `get "kitchen", to: "kitchen#index"`

## Implementation Steps

### Step 1: Database — add action tracking columns
- [ ] Rollback `line_items` migration, add three nullable foreign keys, re-migrate

```ruby
t.references :ready_by, null: true, foreign_key: { to_table: :users }
t.references :cancelled_by, null: true, foreign_key: { to_table: :users }
t.references :delivered_by, null: true, foreign_key: { to_table: :users }
```

- [ ] Add associations to LineItem model:

```ruby
belongs_to :ready_by, class_name: "User", optional: true
belongs_to :cancelled_by, class_name: "User", optional: true
belongs_to :delivered_by, class_name: "User", optional: true
```

### Step 2: Update LineItemsController — set actor + Turbo responses
- [ ] `#ready`: set `ready_by: Current.user`, respond to `turbo_stream` format
- [ ] `#cancel`: set `cancelled_by: Current.user` (already responds to turbo_stream)
- [ ] `#deliver`: set `delivered_by: Current.user`, respond to `turbo_stream` format
- [ ] Create `ready.turbo_stream.erb` — replace line item card, update order header/summary
- [ ] Create `deliver.turbo_stream.erb` — replace line item card, update order header/summary

### Step 3: Kitchen broadcasting — extend LineItem model
- [ ] Extend `broadcast_item_update` to also broadcast to `store_#{store_id}_kitchen`:

| Event | Turbo Stream Action | Target |
|-------|-------------------|--------|
| Item becomes COOKING | `append` to `kitchen-queue` | New card appears |
| Item becomes READY | `replace` kitchen card | Card updates to ready state |
| Item becomes CANCELLED | `remove` kitchen card | Card disappears |
| Item becomes DELIVERED | `remove` kitchen card | Card disappears |

- [ ] Also broadcast queue count update (replace a `#kitchen-queue-count` element)

### Step 4: KitchenController#index

```ruby
class KitchenController < ApplicationController
  def index
    @line_items = LineItem
      .joins(:order)
      .where(orders: { store_id: Current.store.id })
      .where(status: [:cooking, :ready])
      .includes(:order => [:spot, :user], :line_item_components => :component, :product => {})
      .order(created_at: :asc)
  end
end
```

### Step 5: Kitchen views

**`kitchen/index.html.erb`:**

```
+--------------------------------------------------------------------+
| MayStore                          Bienvenido, Cocina 1 [Salir]     |  <- existing navbar
+--------------------------------------------------------------------+
|                                                                    |
|  COCINA                                                            |  <- h1 page title
|  Ordenado por: Más antiguo primero               Cola: 6          |
|                                                                    |
|  [line_item cards sorted oldest first...]                          |
|                                                                    |
+--------------------------------------------------------------------+
```

- `turbo_stream_from "store_#{Current.store.id}_kitchen"` for real-time updates
- Cards in `<div id="kitchen-queue">`
- Queue count in `<span id="kitchen-queue-count">`
- `data-controller="kitchen-audio"` on queue container

**`kitchen/_line_item_card.html.erb`** — each card `<div id="kitchen_line_item_#{id}">`:

- **Header:** Wait time ("Esperando X min"), spot name (or "PARA LLEVAR"), order code, order time, waiter name
- **Oldest COOKING item** highlighted: "MÁS ANTIGUO"
- **READY items** show: "LISTO - Esperando X min para recoger"
- **Body:** Product name (bold, uppercase), modified ingredients with `*` marker, extras with `+` prefix and quantity, special notes. **No prices.**
- **Actions:** COOKING → `[Listo] [Cancelar]`, READY → `[Cancelar]` only

### Step 6: Stimulus — kitchen-audio controller

```javascript
// kitchen_audio_controller.js
// Listens for turbo:before-stream-render events
// On `append` actions only → plays ~800Hz beep for 200ms via Web Audio API
```

### Step 7: I18n

Keys already exist in `config/locales/es.yml` under `kitchen:`. Verify coverage, add any missing keys.

### Step 8: Tests

**KitchenControllerTest:**
- `test "index shows cooking and ready line items"`
- `test "index excludes delivered and cancelled items"`
- `test "index orders by oldest first"`
- `test "index requires authentication"`

**LineItem model test additions:**
- `test "ready sets ready_by to current user"`
- `test "cancel sets cancelled_by to current user"`
- `test "deliver sets delivered_by to current user"`

### Step 9: Update docs

- [ ] Update `docs/models.md` — add `ready_by`, `cancelled_by`, `delivered_by` fields to LineItem
- [ ] Update `docs/turbo-streams.md` — add `store_{store_id}_kitchen` channel documentation

## Out of scope (future)

- **Takeouts channel** (`store_#{store_id}_takeouts`) — will be its own plan
- Kitchen-specific role restrictions — all roles can access all screens per project rules
