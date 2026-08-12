# Item substitution ("cambiar" an item for another)

**Status:** backlog. The capability already exists as two steps; this plan is about
making it one, and about telling the kitchen that the two are related.

## The situation

A customer orders an oreo coffee and a nutella crepe. Two minutes later, with the
order already sent to the kitchen, they change their mind: chai latte instead of
the oreo coffee.

This is already possible today, and nothing is blocked:

1. **Cancelar** on the oreo coffee. The item goes `cancelled`, leaves the kitchen
   queue, stops counting towards the total, and stays on the bill as `CANCELADO`.
2. **Agregar Productos** → chai latte. `Order#add_item!` works while the order is
   `cooking`, `ready` or `delivered`, and flips a `ready`/`delivered` order back to
   `cooking`.

So this is not a missing feature. It is two taps that nobody has named, and two
things that are genuinely missing around it.

## What is actually missing

1. **Nothing records that it was a substitution.** The kitchen sees one item
   disappear and an unrelated one appear. A barista halfway through pouring the
   oreo coffee has no way to know the chai latte replaces it. There is no
   `replaces_line_item_id`, and the printed ticket cannot say so either.
2. **Nothing records why the first item died.** See
   `26-08-11-cancellation-reasons.md`, which is worth doing first and is useful on
   its own.

## Why this is not urgent

The two-step flow works, costs two taps, and produces the correct bill and the
correct kitchen queue. A dedicated swap couples line items to each other and shows
up in three places that currently do not care (the bill, the kitchen ticket, and
anything summing cancelled items), which is a lot of surface area to buy two taps.

Do it when swapping turns out to be frequent, or when the kitchen complains that
cancellations and new items arrive with no relationship between them.

## Design when it is time

### Data

```ruby
add_reference :line_items, :replaces, null: true, foreign_key: { to_table: :line_items }
```

One column, on the *new* item, pointing at the one it replaced. Reads naturally
("this chai latte replaces that oreo coffee") and leaves the cancelled item
untouched, so every existing query keeps working.

### Action

A `Cambiar` button next to `Cancelar` on a `cooking` or `ready` item. It opens the
same product browser used by `Agregar Productos`, and on selection performs both
halves in one transaction:

```ruby
def substitute!(product:, by:)
  transaction do
    cancel!(by: by)
    order.add_item!(product: product).tap { |item| item.update!(replaces: self) }
  end
end
```

One transaction matters: a cancel that lands without its replacement leaves the
customer with nothing ordered, and a replacement without the cancel double-charges.

### Kitchen ticket

The point of the link. `Receipt::KitchenTicket` prints the substitution as one
instruction rather than two unrelated lines:

```
CHAI LATTE
  >> CAMBIO: en lugar de OREO COFFEE
```

`EscPos::Document#wrapped` already handles the indent; see
`docs/references/thermal-printing.md`.

### Screens

The waiter's item list should show the same relationship, so the pair reads as one
decision rather than a cancellation and an unrelated addition.

### Tests

- `substitute!` cancels the old item and creates the new one in one transaction,
  and rolls both back if either fails.
- The order total reflects only the new item.
- The kitchen ticket names the replaced product.
- A `delivered` item cannot be substituted, for the same reason it cannot be
  cancelled: the food is on the table.

## Open question

**Who pays when the drink was already made?** Today a cancelled item leaves the
total silently, so the store absorbs it with no record. If a substitution after
the barista has poured should sometimes still be charged, that is a pricing
decision and a different feature from swapping, and it needs its own plan. Until
then, substitution always means the store eats the first item.
