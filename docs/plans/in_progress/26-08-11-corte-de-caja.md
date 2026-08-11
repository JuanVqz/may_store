# Corte de Caja (daily cash closing)

**Status:** in progress. Lives under Admin, daily.

## Decisions taken (2026-08-11)

The open questions below were answered before implementation:

1. **Cortes chain.** A corte starts where the previous one was closed and runs to
   the moment it is closed itself. Revised on 2026-08-11 after using it: the
   original all-day window was wrong, because a store may want to cut the drawer
   per shift, per cashier, or twice on a busy Saturday, and a calendar day cannot
   express that. Chaining also makes the guarantee stronger than a fixed window
   ever could: no sale is counted twice or lost between two cortes.

   For a store's first ever corte there is no previous one, so it starts at the
   store's earliest payment, which means nothing already sold goes uncounted.

   Only **one corte is open at a time**, and that is what keeps the chain honest:
   a second open corte would overlap the first and count the same money twice, so
   `open_current!` reuses the open one instead of rivalling it.

   Per-store opening hours are no longer needed for this. A store that wants a
   06:00-22:00 corte simply closes it at 22:00.
2. **No permission boundary.** Everybody can see and do everything, exactly as the
   rest of the app works today. Corte de caja lives under Admin because that is its
   default screen, not because it is restricted. Boundaries get picked up as their
   own piece of work once the feature is settled.
3. **As many cortes as wanted**, per shift or per cashier. See 1.
4. **Closing locks nothing else.** It fixes this corte's period end, takes one last
   reading so a sale rung up mid-count still lands here, and records the result.

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

### 2. Period boundaries — done

Settled by chaining, see decision 1. `CashClosing.open_current!` opens the corte
that runs from the last closed one up to now; `refresh_expected!` moves that end
forward while it stays open; `close!` fixes it.

The wireframe's `06:00 - 22:00` is a *result* of this rather than configuration: a
store that opens at six and closes at ten gets exactly that period by closing its
corte at ten.

Nothing enforces one corte per day, deliberately. What is enforced is one *open*
corte per store, since two would overlap and count the same money twice.

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

All four of the original questions are answered in the decisions above. What is
left:

1. **A sale backdated into a closed corte is silently uncounted.** Payments are
   read by `paid_at`, so a payment written with a `paid_at` inside an
   already-closed period lands in no corte at all: the closed one will not be
   recomputed and the open one starts later. Today nothing backdates a payment, so
   this is a trap rather than a bug, but it is the one worth watching.
2. **Nothing stops two people counting the same open corte from two screens.** The
   last save wins. Fine for one till; worth revisiting for a store with two.
3. Permission boundaries, deliberately deferred (decision 2).

## Not in scope

Cash movements during the day (paid-outs, float, deposits). The model has no
concept of them, and adding one is a separate plan.
