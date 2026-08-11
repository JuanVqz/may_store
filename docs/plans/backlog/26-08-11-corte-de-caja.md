# Corte de Caja (daily cash closing)

**Status:** backlog, ready to start. Admin-only, once per day.

The domain layer already exists and is tested. This plan is about the missing
half: routes, controller, screens, and a printed corte for the drawer.

## What already exists

Do not rebuild these.

| Piece | State |
| --- | --- |
| `CashClosing` | Model, `open`/`closed` enum, `calculate_expected!`, `close!`, `total_*_cents` roll-ups |
| `CashClosingLine` | One row per payment method, `difference_cents` computed in a `before_save` |
| Schema | `cash_closings`, `cash_closing_lines`, indexed on `(store_id, period_start, period_end)` |
| Locales | `cash_closing.*` and `cash_closing_statuses.*` in `es.yml`, fully translated |
| Tests | `test/models/cash_closing_test.rb`, `cash_closing_line_test.rb`, fixtures |
| Wireframes | `docs/references/wireframes.md` Screen 13 (admin dashboard) and Screen 14 (the corte) |

`calculate_expected!` sums `Payment.amount_cents` for **closed orders only**,
joined on `paid_at` within the period, grouped per active payment method.

## What is missing

Everything user-facing. There is no controller, no route, and no view.

## Steps

### 1. Routes and controller

```ruby
namespace :admin do
  resources :cash_closings, only: [:index, :show, :new, :create, :update]
end
```

- `new` previews today's expected totals without persisting, so an admin can look
  without creating a record.
- `create` builds the `CashClosing` for the period and calls `calculate_expected!`.
- `update` saves the counted `actual_cents` per line plus notes, and closes the
  corte when the submit button says so.

Admin-only. Note the existing convention: **role is the default screen, not a
permission**, and `flash.not_authorized` already exists in `es.yml`. Decide
deliberately whether corte de caja is the first genuine permission boundary in
this app, or whether any role may perform it. If it is a real boundary, that is
a decision worth writing to `docs/plans/decisions/`.

### 2. Period boundaries

The day is not midnight-to-midnight for a cafe. Wireframe Screen 14 shows
`06:00 - 22:00`. Decide where those come from, in order of preference:

1. Store-level opening hours (new columns, a migration, and the most correct).
2. First and last payment of the day (no configuration, but a slow morning
   silently narrows the period).
3. `Time.zone.now.all_day` (simplest, wrong for a shop open past midnight).

Whichever it is, `period_start`/`period_end` are already `null: false`, so the
choice has to be explicit. Also decide what happens when two cortes are attempted
for the same day: the index on `(store_id, period_start, period_end)` is not
unique, so nothing currently stops it.

### 3. Screens

Follow Screen 14. One row per active payment method: expected (computed, read
only), actual (the admin types what they counted), difference (live).

- Compute the difference client-side as they type, in a Stimulus controller,
  the same pattern `payment_form_controller.js` already uses for change.
- `expected` must be visibly not-editable, since it is the number the count is
  checked against.
- Cash is the only line that usually differs. Consider ordering cash first.

Screen 13 also wants the day's summary on the admin dashboard: orders closed,
orders cancelled, day total, and totals per payment method. `Order.today` and the
same payment join give all of it.

### 4. Print the corte

This is why the plan is worth doing now: the thermal printer works, and a corte
that prints is a corte that can be signed and dropped in the drawer.

Add `Receipt::CashClosing` next to `Receipt::Bill`, and a nested
`resource :receipt` under the corte, reusing `EscPosStreaming`. Content:

```
        CAFE DELICIAS
       CORTE DE CAJA
   12 ago 2026  06:00-22:00
   Realizado por: Admin Principal
==========================================
METODO          ESPERADO  REAL   DIFERENCIA
Efectivo        $3,120.00 $3,070.00 -$50.00
...
------------------------------------------
TOTAL           $6,240.00 $6,190.00 -$50.00
==========================================
Notas: faltaron $50, posible error
       en cambio de mesa 8

        Firma: ____________________
```

Note the width problem: four money columns do not fit in 42 columns. Either drop
to two lines per method, or print expected/actual/difference stacked under each
method name. `EscPos::Document#row` is a two-column primitive, so a three-column
layout needs either a new helper or per-method blocks. Prefer per-method blocks;
see `docs/references/thermal-printing.md`.

Print at close, not at create, and include the signature line.

### 5. Tests

- Controller: admin reaches it, other roles get whatever the decision in step 1
  says, tenant scoping holds, `update` persists actuals and closes.
- Model: the period boundary logic, and same-day double-corte behaviour.
- `Receipt::CashClosing`: totals, negative differences, and the notes wrapping.
- System: type an actual, see the difference update, close the corte.

## Open questions

1. Where do period boundaries come from? (step 2)
2. Is corte de caja the app's first real permission boundary? (step 1)
3. One corte per day enforced, or many allowed?
4. Does closing a corte lock anything, or is it purely a record? Payments after a
   close would currently land outside the closed period with nothing flagging it.

## Not in scope

Cash movements during the day (paid-outs, float, deposits). The model has no
concept of them, and adding one is a separate plan.
