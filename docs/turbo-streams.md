# Real-time Updates — Turbo Morph & Streams

## Overview

MayStore uses ActionCable-backed Turbo to push updates to connected browsers in real-time. No polling — updates arrive instantly via WebSocket.

We use two complementary approaches:
- **Turbo Morph** — for broadcasting state changes across pages (status updates, counters, progress)
- **Turbo Streams** — for HTTP responses that modify the requesting page's DOM (add/remove items)

## Architecture

```
                    ┌─────────────────────────────────────────────────────┐
                    │                    RAILS SERVER                     │
                    │                                                     │
                    │  ┌─────────────┐         ┌──────────────────────┐  │
                    │  │ LineItem    │         │ Order                │  │
                    │  │             │         │                      │  │
                    │  │ after_update│         │ after_update_commit  │  │
                    │  │ _commit:    │         │ broadcast_refresh_to:│  │
                    │  │             │         │  • order_{id}        │  │
                    │  │ broadcast_  │         │  • store_{id}_tables │  │
                    │  │ refresh_to: │         │  • store_{id}_       │  │
                    │  │  • order_   │         │    takeouts          │  │
                    │  │    {id}     │         │                      │  │
                    │  │  • kitchen  │         └──────────────────────┘  │
                    │  │  • tables   │                                   │
                    │  │  • takeouts │                                   │
                    │  └─────────────┘                                   │
                    └────────────────────────┬──────────────────────────┘
                                             │
                                   ActionCable (WebSocket)
                                             │
                    ┌────────────┬────────────┼────────────┬─────────────┐
                    ▼            ▼            ▼            ▼             ▼
              ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
              │ /kitchen │ │ /orders/ │ │ /tables  │ │/takeouts │ │ /orders/ │
              │          │ │  {uuid}  │ │          │ │          │ │  {uuid}  │
              │ Cocina 1 │ │ Mesero 1 │ │ Mesero 2 │ │ Mesero 3 │ │ Mesero 1 │
              │          │ │          │ │          │ │          │ │ (phone)  │
              └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘
                   │            │            │            │             │
                   ▼            ▼            ▼            ▼             ▼
               MORPH        MORPH        MORPH        MORPH         MORPH
              (re-render   (re-render   (re-render   (re-render    (re-render
               full page)   full page)   full page)   full page)    full page)
```

## Turbo Morph (broadcast_refresh_to)

Used for **all real-time state synchronization**. When a model changes, it tells all subscribed pages to refresh themselves. Turbo morphs the DOM (smart diff) instead of replacing it, preserving scroll position, focus, and form state.

### How it works

**1. View opts in to morph and subscribes to a channel:**
```erb
<%%= turbo_refreshes_with method: :morph, scroll: :preserve %>
<%%= turbo_stream_from "store_#{Current.store.id}_kitchen" %>
```

**2. Model broadcasts a refresh on change:**
```ruby
after_update_commit :broadcast_refreshes, if: :saved_change_to_status?

def broadcast_refreshes
  broadcast_refresh_to "order_#{order_id}"
  broadcast_refresh_to "store_#{order.store_id}_kitchen"
  broadcast_refresh_to "store_#{order.store_id}_tables"
  broadcast_refresh_to "store_#{order.store_id}_takeouts"
end
```

**3. Each subscribed browser re-fetches its current page and Turbo morphs the diff into the DOM.**

### Channels

| Channel | Subscribers | Triggers |
|---------|-------------|----------|
| `order_{id}` | Order show page | LineItem status change, Order status change |
| `store_{id}_kitchen` | Kitchen queue | LineItem status change, Order confirm, Order add_item |
| `store_{id}_tables` | Tables index | LineItem status change, Order status change |
| `store_{id}_takeouts` | Takeouts index | LineItem status change, Order status change |

### Why morph instead of targeted broadcasts

We started with targeted broadcasts (`broadcast_replace_to` with specific partials and DOM targets) but switched to morph because:

- **70 lines of broadcast code → 4 lines per model**
- **No stale data** — morph re-renders with fresh server data every time
- **No DOM target coordination** — no matching partial names, target IDs, or stream actions
- **Free features** — queue count, empty state, readiness progress all update automatically
- **Works from any page** — kitchen actions don't need to know about order view DOM structure

See `plans/decisions/26-03-13-keep-targeted-broadcasts.md` for the full decision history.

## Turbo Streams (HTTP responses)

Used for **actions on the requesting page only** — adding items, removing items, updating the product browser. These modify the DOM of the page that made the request.

### When to use Turbo Streams vs Morph

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   User clicks a button                                      │
│                                                             │
│   Does the action need to update OTHER connected pages?     │
│                                                             │
│   YES → Morph handles it                                    │
│         (via broadcast_refresh_to in model callbacks)        │
│         Controller just redirects back.                      │
│                                                             │
│   Does the action need to update THIS page's DOM            │
│   in a way morph can't handle? (add/remove elements,        │
│   clear forms, close modals)                                │
│                                                             │
│   YES → Turbo Stream HTTP response                          │
│         (controller responds with .turbo_stream.erb)         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Current Turbo Stream responses

| Action | Template | What it does |
|--------|----------|-------------|
| `LineItems#create` | `create.turbo_stream.erb` | Prepends new item to order list, updates header/summary, clears customization form |
| `LineItems#destroy` | `destroy.turbo_stream.erb` | Removes item from order list, updates summary |

### Current redirect-only actions (morph handles updates)

| Action | Controller behavior | Morph updates |
|--------|-------------------|---------------|
| `LineItems#ready` | `redirect_back` | Kitchen card, order view, tables, takeouts |
| `LineItems#deliver` | `redirect_back` | Kitchen card, order view, tables, takeouts |
| `LineItems#cancel` | `redirect_back` | Kitchen card, order view, tables, takeouts |

## Flow Example: Kitchen marks item "Listo"

```
1. Kitchen staff clicks "Listo" on a cappuccino card
   ┌──────────────────────────────┐
   │  PATCH /orders/{id}/         │
   │  line_items/{id}/ready       │
   └──────────────┬───────────────┘
                  │
2. Controller:    ▼
   line_item.mark_ready!(by: Current.user)
   redirect_back
                  │
3. Model:         ▼
   LineItem status: cooking → ready
   after_update callback:
     order.check_ready! (may transition order to "ready" if all items ready)
   after_update_commit:
     broadcast_refresh_to "order_{id}"
     broadcast_refresh_to "store_{id}_kitchen"
     broadcast_refresh_to "store_{id}_tables"
     broadcast_refresh_to "store_{id}_takeouts"
                  │
4. Results:       ▼
   ┌────────────────────────────────────────────────────────┐
   │ /kitchen     → card changes from "Listo" button to     │
   │                "Marcar Entregado" button                │
   │                queue count updates                      │
   │                                                        │
   │ /orders/{id} → item badge: orange → green               │
   │                order status may change to "Listo"       │
   │                                                        │
   │ /tables      → table card status updates                │
   │                "1 de 2 listos" → "2 de 2 listos"       │
   │                                                        │
   │ /takeouts    → order card status updates                │
   │                progress counters update                  │
   └────────────────────────────────────────────────────────┘
```

## ActionCable Config

- **Development:** `async` adapter (in-memory, single process)
- **Production:** `solid_cable` adapter (database-backed, works across processes)
- Config: `config/cable.yml`
