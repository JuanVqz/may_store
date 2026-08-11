# Corte de Caja (daily cash closing)

**Status:** in progress. Lives under Admin, daily.

## Decisions taken (2026-08-11)

The open questions below were answered before implementation:

1. **A corte counts the payments no corte has claimed yet**, and claims them when
   it closes. Membership is a foreign key on `payments.cash_closing_id`, not a
   time window.

   This went through two earlier designs, both wrong, and the reasons are worth
   keeping:

   - *All-day window.* Could not express cutting the drawer per shift, per
     cashier, or twice on a busy Saturday.
   - *Chained windows* (each corte from the last close to now). Better, but still
     selected by `paid_at`, so a payment written with a `paid_at` inside an
     already-closed period was counted by nobody: too late for the corte covering
     that time, too early for the next one.

   Claiming removes the whole class of problem. Anything unclaimed will be picked
   up by the next corte no matter when it was paid, so money cannot fall between
   two cortes, and a closed corte's totals can never move because it counts
   exactly the rows it claimed.

   `period_start` and `period_end` survive as **description**, not selection: they
   say when the shift ran, and appear on screen and on the printed corte. Nothing
   is counted by them.

   Only **one corte is open at a time**, so two counts cannot claim the same
   money. `open_current!` reuses the open one instead of rivalling it.

   Per-store opening hours are not needed. A store that wants a 06:00-22:00 corte
   simply closes it at 22:00.

2. **Order status does not filter the count.** A `Payment` row means money reached
   the drawer; whether the food was served is a different question. In particular
   `cancel!` does not touch payments, so an order paid and then cancelled keeps
   its payments, and the earlier `orders.status = :closed` filter left that money
   counted by **no corte at all**, permanently. A partial payment on an order
   still open counts for the same reason: the cash is in the till now.
3. **No permission boundary.** Everybody can see and do everything, exactly as the
   rest of the app works today. Corte de caja lives under Admin because that is its
   default screen, not because it is restricted. Boundaries get picked up as their
   own piece of work once the feature is settled.
4. **As many cortes as wanted**, per shift or per cashier. See 1.
5. **Closing takes a final reading, claims the payments it counted, and freezes.**
   All three in one transaction: a claim without matching totals, or totals
   without the claim, would silently miscount the next corte.

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

`calculate_expected!` originally summed `Payment.amount_cents` for closed orders
only, joined on `paid_at` within the period. Both of those filters are gone: see
decisions 1 and 2. It now sums the payments this corte counts, grouped per active
payment method.

## What is missing

Everything user-facing. There is no controller, no route, and no view.

## Steps

### 1. Routes and controller — done

```ruby
namespace :admin do
  resources :cash_closings, only: [:index, :show, :new, :create, :update]
end
```

Built as `index`, `show`, `create`, `update`; `new` was dropped, since `create`
reuses the open corte rather than creating a rival, so there is nothing to preview.
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

### 3. Screens — done

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

### 4. Print the corte — done

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

Four money columns do not fit in 42 columns, so each method got a block of its
own. A test asserts no printed line exceeds the paper width.

Print at close, not at create, and include the signature line.

### 5. Tests — done

- Controller: admin reaches it, other roles get whatever the decision in step 1
  says, tenant scoping holds, `update` persists actuals and closes.
- Model: the period boundary logic, and same-day double-corte behaviour.
- `Receipt::CashClosing`: totals, negative differences, and the notes wrapping.
- System: type an actual, see the difference update, close the corte.

## Open questions

1. **Refunds cannot be expressed, so the count can overstate the drawer.** Now that
   a cancelled order's payments are counted, handing money back to a customer is
   invisible: the payment still reads as cash on hand. There is no refund concept
   in the app, no negative payment and no `refunded_at`. This is the most
   important gap in the feature and needs a domain decision:

   - a refund as a negative `Payment` (simplest, keeps one ledger, makes the corte
     arithmetic work with no special cases), or
   - a `refunded_at`/`refunded_cents` on `Payment` (keeps the original amount
     visible, but every sum has to remember to subtract), or
   - nothing, and the store handles refunds as a note on the corte.

   Until this is settled, a store that refunds will see a shortfall equal to the
   refund and will have to explain it in the notes.

2. **Nothing stops two people counting the same open corte from two screens.** The
   last save wins. Fine for one till; worth revisiting for a store with two.

3. **A payment on an order that is never closed is counted at once.** That is the
   intent, but it means `Esperado` can include money for a table still eating. For
   a drawer count that is correct; if it ever reads as wrong to a cashier, the
   answer is to show which payments make up a line, not to filter by order status.

4. Permission boundaries, deliberately deferred (decision 3).

## Not in scope

Cash movements during the day (paid-outs, float, deposits). The model has no
concept of them, and adding one is a separate plan.
