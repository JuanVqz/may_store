# Why was this item cancelled?

**Status:** backlog, ready to build. Small, and useful on its own.

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
- Next to the cancelled item, show the reason as small text with a way to correct
  it. Cheapest version: a `PATCH` per reason behind a dropdown, no new screen.
- The kitchen's cancel button could default to `kitchen_error` instead, since a
  cook cancelling their own item usually means exactly that. Worth deciding
  deliberately rather than assuming: it is also the cook who cancels when the
  waiter relays "they changed their mind".

### Where it pays off

An admin view summing cancellations by reason over a period, which is the whole
point. `Order.today` plus a group on `cancellation_reason` gives it. Natural home
is the admin dashboard next to the corte, since both answer "how did today go".

### Tests

- `cancel!` with no reason records the default.
- `cancel!` with an explicit reason records that instead.
- An unknown reason fails validation rather than raising on assignment (the
  `validate: true` pattern `Category#station` already uses).
- Items cancelled before this existed keep `nil` and do not break the summary.

## Deliberately not included

Cancelling a *whole order* has the same question, and `Order#cancel!` cascades to
its items. Adding a reason there means either asking twice or inventing a rule for
which reason the items inherit. Item-level first; order-level once the item-level
data shows what people actually pick.
