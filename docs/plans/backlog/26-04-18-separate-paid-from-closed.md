# Separate "paid" from "closed" on orders

## Status

**DECISION: Rejected - going with Option B instead (Today's Orders list)**

## Problem

Today `close!` only checks `fully_paid?`. So if a waiter pays while items are still COOKING or READY, the order flips straight to CLOSED:

- `orders/show` renders the closed confirmation — waiter loses the order page.
- Items remain in their own state (COOKING/READY) and still appear in the kitchen queue.
- Kitchen keeps prepping food for a "ghost" order; waiter cannot mark items READY or DELIVERED.

## Original proposal (Option A - REJECTED)

Split the two concepts: add `paid_at` timestamp, `Order#pay!`, require both paid AND delivered to close.

**Why rejected:** Paid-but-open orders allow adding items → who pays for the additional items? Either prevent adds (bad UX for "one more coffee") or allow complex split payments (too much complexity).

## New approach (Option B - ACCEPTED)

Keep `close!` behavior (closes on payment when fully paid). Add "Today's Orders" list to make ghost orders visible.

### Scope

- `OrdersController#index` — list scoped to `today`, ordered by created_at desc
- Add "Órdenes del Día" link in sidebar after "Para Llevar"
- Order row shows: code, spot, status badge, total, item counts
- Click to view order (including closed ones)
- Kitchen queue behavior unchanged

### Done when

- Waiter can access "Órdenes del Día" and see all today's orders
- Can click into any order to verify delivery status
- Pay-after-delivery flow unchanged (closes on payment)
- Pay-before-delivery creates ghost orders but they're visible in the list

---

## Additional Changes (2026-04-19)

### received_cents always required

- `Payment.received_cents` now: default 0, null false
- Validation: presence required, must be >= amount_cents
- For cash payments: waiter enters amount (field auto-focused)
- For non-cash: auto-fills to amount_cents (no change needed)
- Form always shows received field (no longer hidden for non-cash)
