# Model Concerns Extraction

Extract behavioral concerns from Order and LineItem following fizzy's adjective-style pattern.

## Steps

- [x] Create `app/models/order/stateful.rb` — extract status transitions, colors, labels, broadcast callback
- [x] Create `app/models/order/code_generable.rb` — extract code generation + OrderCounter logic
- [x] Create `app/models/line_item/stateful.rb` — extract status transitions, colors, labels, order status cascade, broadcast callback
- [x] Update `app/models/order.rb` — include concerns, remove extracted code
- [x] Update `app/models/line_item.rb` — include concern, keep `InvalidTransition` in base class, remove extracted code
- [x] Run tests — pure refactor, all existing tests pass (115 runs, 271 assertions)

## Design

See `docs/superpowers/specs/2026-03-18-model-concerns-extraction-design.md` for full details.

## File structure

```
app/models/
  order.rb
  order/
    stateful.rb
    code_generable.rb
  line_item.rb
  line_item/
    stateful.rb
```
