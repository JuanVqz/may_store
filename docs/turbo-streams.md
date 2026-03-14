# Turbo Streams — Real-time Updates

## Overview

MayStore uses ActionCable-backed Turbo Streams to push status changes to connected browsers in real-time. No polling — updates arrive instantly via WebSocket.

## Architecture

```
┌─────────────┐     status change      ┌──────────────┐
│  Kitchen UI  │ ──────────────────────>│  LineItem     │
│  (browser)   │   PATCH /ready         │  model        │
└─────────────┘                         └──────┬───────┘
                                               │
                                     after_update_commit
                                               │
                                    ┌──────────▼───────────┐
                                    │  broadcast_replace_to │
                                    │  "order_{id}"         │
                                    └──────────┬───────────┘
                                               │
                              ActionCable (WebSocket)
                                               │
                    ┌──────────────────────────┼──────────────────────┐
                    ▼                          ▼                      ▼
          ┌─────────────────┐      ┌─────────────────┐    ┌─────────────────┐
          │  Waiter viewing  │      │  Another waiter  │    │  Kitchen queue   │
          │  order show page │      │  on tables page  │    │  (future)        │
          └─────────────────┘      └─────────────────┘    └─────────────────┘
```

## Channels & Subscriptions

| Channel name                  | Who subscribes                  | What gets broadcast               |
|-------------------------------|---------------------------------|-----------------------------------|
| `order_{id}`                  | Order show page (`orders/show`) | Line item partial on item status change. Full order partial on order status change. |
| `store_{id}_tables`           | Tables index page               | Table card partial on order status change (e.g. cooking → ready updates the table grid). |

## How it works

### 1. View subscribes

```erb
<%%= turbo_stream_from "order_#{@order.id}" %>
```

This creates an ActionCable subscription. Turbo automatically handles incoming stream messages and replaces DOM elements by `id`.

### 2. Model broadcasts on change

**Order** (`app/models/order.rb`):
```ruby
after_update_commit :broadcast_order_update, if: :saved_change_to_status?
```

Broadcasts to two channels:
- `order_{id}` → replaces `#order_{id}` (the entire order view)
- `store_{id}_tables` → replaces `#table_{table_id}` (the table card)

**LineItem** (`app/models/line_item.rb`):
```ruby
after_update_commit :broadcast_item_update, if: :saved_change_to_status?
```

Broadcasts to:
- `order_{order_id}` → replaces `#line_item_{id}` (individual item card)

### 3. Partials used for broadcasts

| Partial                          | DOM target ID        | Used by              |
|----------------------------------|----------------------|----------------------|
| `orders/_order.html.erb`         | `order_{id}`         | Order status changes |
| `line_items/_line_item.html.erb` | `line_item_{id}`     | Item status changes  |
| `tables/_table.html.erb`         | `table_{table_id}`   | Table grid updates   |

## Flow Example: Kitchen marks item ready

```
1. Kitchen clicks "Listo" on a line item
2. PATCH request → LineItemsController#ready
3. line_item.mark_ready! → status = "ready"
4. after_update callback:
   - order.check_ready! (may transition order to "ready")
5. after_update_commit callback:
   - broadcast_replace_to "order_{id}" with _line_item partial
   - If order status also changed: broadcast _order + _table partials
6. All browsers subscribed to "order_{id}" see the item badge
   change from orange (Preparando) to green (Listo) instantly
7. Tables page sees the table card update its status color
```

## ActionCable Config

- **Development:** `async` adapter (in-memory, single process)
- **Production:** `solid_cable` adapter (database-backed, works across processes)
- Config: `config/cable.yml`

## Design Note: Why Not Turbo Morph?

Turbo 8 supports page-level morph refreshes (`broadcasts_refreshes` + `<meta name="turbo-refresh-method" content="morph">`), which would simplify broadcast code significantly. We evaluated this for the single-page order flow and decided to keep targeted broadcasts for now because the current approach is already working and tested.

Morph can be adopted per-page later without affecting the rest of the app — it's scoped by meta tags in specific views. See `plans/decisions/26-03-13-keep-targeted-broadcasts.md`.
