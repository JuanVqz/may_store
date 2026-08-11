# Itemized extras pricing on the bill

**Status:** backlog. Deliberately not done. The grouped price is the default, and
this is only worth building if a customer or the tax authority asks for it.

## Today's behaviour

An item prints one price, which already includes its extras:

```
#1 Espresso                             $40.00
    Espresso Shot: Normal
    + Espresso Shot x1
```

The espresso is $25 and the extra shot is $15, but the receipt shows `$40.00`
and names the extra without pricing it. `LineItem#calculate_total!` sums
`base_price_cents` plus the extras' `unit_price_cents`, so the breakdown exists
in the data; it is simply not printed.

## Why it is parked

The grouped total is what a customer checks: it matches the menu price plus what
they asked for, and it reconciles against the order total. Pricing every extra
turns a three-line item into six and roughly doubles the paper for a large order.
Thermal paper is the real cost here, not screen space.

## What it would look like

```
#1 Espresso                             $40.00
    Espresso Shot: Normal
    + Espresso Shot x1                  $15.00
      (base $25.00)
```

## Triggers to build it

1. A customer disputes a total and the receipt cannot explain it.
2. Tax or invoicing rules require per-line pricing.
3. Extras get expensive enough relative to the base price that the grouped total
   looks wrong to customers.

## Implementation notes

- `Receipt::Bill#details` already partitions ingredients from extras and groups
  extras by `component_id`; the price is `group.sum(&:unit_price_cents)`, since a
  group is one component ordered N times.
- Print the base price only when extras exist, otherwise it repeats the line total.
- Ingredients are portions, not charges, and stay unpriced.
- Mirror it in `orders/bill.html.erb` so screen and paper agree, and add a
  `Receipt::Bill` test asserting base plus extras equals the printed line total.
- Consider making it a store setting rather than a global change: a cafe with
  cheap extras wants it off, a bar with expensive add-ons wants it on.
