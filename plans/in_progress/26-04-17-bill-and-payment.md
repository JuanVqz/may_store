# Bill & Payment (Full Payment)

## Goal

Waiter can request bill, choose payment method, confirm payment, close order. Table frees up. Split payment deferred to future plan.

## Reference

- `docs/wireframes.md` — Screens 9, 11, 12
- `docs/models.md` — Order status flow

## Scope

**In**: Screen 9 (bill + single payment), Screen 11 (closed confirmation), browser print.
**Out**: Screen 10 (split payment), Screen 12 (keep current cancel → redirect to tables with flash).

## Decisions

- `Payment` model already exists (`order_id`, `payment_method_id`, `amount_cents`, `paid_at`, `notes`).
- `PaymentMethod` is a per-store lookup table, not an enum. Store-configurable for free.
- Seeded methods: Efectivo, Mercado Pago, Transferencia. Tarjeta removed (MP covers card).
- "Solicitar Cuenta" button visible any time on order page (allows pay-now-receive-later).
- Cancelled items: shown struck-through with "CANCELADO", excluded from total.
- Print: browser `window.print()` + print stylesheet. No backend printer integration.
- UI: only `maquina_components` helpers. No custom CSS beyond tokens.
- Closed orders are terminal — no reopen. See `plans/decisions/26-04-17-closed-orders-terminal.md`.

## Steps

### 1. Payment model
- [x] Migration: `payments` table — already shipped
- [x] `Payment` model: `belongs_to :order, :payment_method`, amount validation — already shipped
- [x] `Order has_many :payments, dependent: :destroy` — already shipped
- [x] Seeds updated: Tarjeta removed, 3 methods remain
- [x] Fixtures updated: `efectivo`, `mercado_pago`, `transferencia` (dropped `tarjeta`)
- [x] Model tests (Payment amount validation, Order#close! guard, payment tracking)

### 2. Order status
- [x] `closed` status in Order enum — already shipped
- [x] `Order#close!` — already shipped
- [x] `total_paid_cents` / `remaining_cents` / `fully_paid?` — already shipped
- [x] Guard: `close!` raises unless `fully_paid?`

### 3. Bill view (Screen 9)
- [x] `OrdersController#bill` action, route `GET /orders/:id/bill`
- [x] View renders with `components/card`, itemized lines, cancelled struck-through, total
- [x] Payment method radio buttons (peer-checked styling)
- [x] I18n keys in `es.yml` (`bill.print`, `bill.total`, `bill.cancelled`, `order.closed`, `order.back_to_tables`)

### 4. Pay action
- [x] `PaymentsController#create` — creates payment for remaining, closes order
- [x] Redirect to `order_path` (renders closed view on show)

### 5. Closed confirmation (Screen 11)
- [x] `orders/_closed.html.erb` partial, rendered from `show` when `closed?`
- [x] "Volver a Mesas" link to `tables_path`

### 6. Print
- [x] Stimulus `print_controller` triggers `window.print()`
- [x] `@media print` rule hides sidebar/header globally
- [x] Bill form buttons use `print:hidden`

### 7. Order page entry
- [x] "Solicitar Cuenta" button wired to `bill_order_path`
- [x] Visible when order has items and is not open/closed/cancelled

### 8. Tests
- [x] Controller tests: bill show, payment create, closed redirect
- [x] Model tests: Order#close! guard, payment tracking

### 9. Docs
- [x] Update `docs/wireframes.md` Screen 9: remove Tarjeta, remove Pago Dividido button (deferred)
- [ ] Update `docs/models.md` with Payment / PaymentMethod if missing

## Done When

- Waiter clicks "Solicitar Cuenta" from active order
- Sees itemized bill with total, cancelled items excluded
- Picks method (efectivo / mercado_pago / transferencia), confirms
- Order closes, table available, sees Screen 11 confirmation
- Can print bill via browser
- All text in Spanish locale
- Tests pass

## Follow-ups (separate plans)

- Split payment (Screen 10)
- Printer integration (ESC/POS or similar) if browser print insufficient
- Admin dashboard payment breakdown (Screen 13)
