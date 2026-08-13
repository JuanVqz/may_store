# Why was this item cancelled?

**Status:** done, 2026-08-12, except the admin summary. See "What was built" below.

## The problem

Cancelling an item removes it from the total and from the kitchen queue, and leaves
no trace of why. So these three are indistinguishable afterwards:

- the customer changed their mind,
- the kitchen made it wrong,
- the product had run out.

They mean completely different things. The first is normal trade, the second is
waste the store paid for and someone should know about, the third is a stock
problem. Today all three vanish equally, so nobody can see a barista remaking six
drinks a shift or a product being cancelled every day because it is never actually
available.

## The constraint that shapes the design

**A waiter must not have to think about this.** They are standing at a table with a
customer waiting. If cancelling grows a required dropdown, the honest outcome is
that whatever sits at the top of the list gets picked every time and the data is
worse than useless, because it will look deliberate.

So: **one tap keeps working exactly as it does now, and records a default.** The
reason is something you can optionally correct, never something that blocks the
cancel.

## Design

### Data

```ruby
add_column :line_items, :cancellation_reason, :string, null: true
```

Nullable rather than defaulted at the database level, so "cancelled before this
feature existed" stays distinguishable from "cancelled and nobody said why". The
model supplies the default instead:

```ruby
CANCELLATION_REASONS = %w[customer_changed_mind kitchen_error out_of_stock duplicate].freeze

enum :cancellation_reason, CANCELLATION_REASONS.index_by(&:itself), validate: { allow_nil: true }

DEFAULT_CANCELLATION_REASON = "customer_changed_mind"

def cancel!(by: nil, reason: DEFAULT_CANCELLATION_REASON)
  # ... existing guards ...
  update!(status: :cancelled, cancelled_by: by, cancellation_reason: reason)
end
```

`customer_changed_mind` is the default because it is both the most common and the
most harmless to assume: guessing it wrongly understates waste rather than
inventing an accusation against the kitchen.

### Screens

- The existing **Cancelar** button stays one tap and sends no reason, so the model
  default applies. Nothing about today's flow changes.
- Next to the cancelled item, a `<select>` that saves on change.
- The kitchen's cancel button could default to `kitchen_error` instead, since a
  cook cancelling their own item usually means exactly that. **Not done**, and
  worth deciding deliberately rather than assuming: it is also the cook who
  cancels when the waiter relays "they changed their mind", so the cook's screen
  is not reliable evidence of a kitchen error.

**Where the selector could go was decided by an existing constraint, not a
preference.** `OrdersController#show` builds `@line_items` with
`.where.not(status: :cancelled)`, so a cancelled item disappears from the active
order screen the moment it is cancelled. The only screens that render cancelled
items are the **bill** and the **closed order**, both of which show them struck
through with `CANCELADO`. The selector lives there. A first attempt put it in
`line_items/_line_item`, where it could never have been seen; a controller test
caught that.

The consequence worth knowing: the waiter who cancelled cannot correct the reason
straight away, because the item is already gone from their screen. The correction
happens at billing time. If that turns out to be too late to remember, the fix is
to show cancelled items on the order screen, not to move the selector.

### Where it pays off — NOT BUILT

An admin view summing cancellations by reason over a period, which is the whole
point of collecting this. `Order.today` plus a group on `cancellation_reason` gives
it. Natural home is the admin dashboard next to the corte, since both answer "how
did today go".

Deliberately left out of the first pass: the data has to exist before a summary of
it is worth designing, and a week of real cancellations will say more about how to
present it than guessing now. This is the obvious next piece of work.

### Tests

- `cancel!` with no reason records the default.
- `cancel!` with an explicit reason records that instead.
- An unknown reason fails validation rather than raising on assignment (the
  `validate: true` pattern `Category#station` already uses).
- Items cancelled before this existed keep `nil` and do not break the summary.

## What was built

| Piece | Where |
| --- | --- |
| `cancellation_reason` column | `20260313000012_create_line_items.rb` (edited in place, per the pre-production migration rule) |
| Enum with `prefix: :reason`, `validate: { allow_nil: true }` | `LineItem` |
| `DEFAULT_CANCELLATION_REASON` | `LineItem` |
| `cancel!(by:, reason: DEFAULT)` | `LineItem::Stateful` |
| The same default on the order-level cascade | `Order::Stateful#cancel!` |
| Reason selector that saves on change | `line_items/_cancellation_reason`, on the bill and the closed order |
| `auto_submit` Stimulus controller | reusable, one line of behaviour |
| `line_items#update` permitting only the reason | `LineItemsController` |
| Spanish labels | `es.yml` under `cancellation_reasons` |

`Order#cancel!` cascades with `update_all`, which bypasses `LineItem#cancel!`
entirely. Without setting the default there too, that cascade would have been the
only path leaving a cancelled item with no reason, making "nobody said" and
"cancelled along with the order" indistinguishable — the exact confusion this
feature exists to remove.

## Deliberately not included

Cancelling a *whole order* has the same question, and `Order#cancel!` cascades to
its items. Adding a reason there means either asking twice or inventing a rule for
which reason the items inherit. Item-level first; order-level once the item-level
data shows what people actually pick.
