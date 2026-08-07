# Strict locals for the remaining 11 partials

**Status: done.** `erb-strict-locals-required` is enabled in `.herb.yml` and all 100 Herb rules are clean.

## Why

`erb-strict-locals-required` was the last Herb rule with real offenses that we had not opted into. Rails strict locals (`<%# locals: (order:, highlight: false) %>`) turn a partial's implicit contract into a declared one: a caller that forgets a local, or passes one the partial does not use, fails loudly instead of rendering `nil` into the page.

The admin views already did this (18 partials declared strict locals, which is why `actionview-strict-locals-first-line` had 18 offenses to autocorrect). The older order/kitchen/table partials did not.

## What was declared

| Partial | Declaration | Call sites |
| --- | --- | --- |
| `line_items/_customization_form` | `(product:, order:, ingredients:, extras:)` | `LineItemsController#new` |
| `line_items/_line_item` | `(item:, order:, highlight: false)` | `orders/show`, `line_items/create.turbo_stream` |
| `kitchen/_line_item_card` | `(item:, oldest_cooking_id: nil)` | `kitchen/index` |
| `orders/_closed` | `(order:)` | `orders/show` |
| `orders/_no_items_message` | `()` | `orders/show`, `line_items/destroy.turbo_stream` |
| `orders/_order_header` | `(order:)` | `orders/show`, `line_items/create.turbo_stream` |
| `orders/_order_summary` | `(order:)` | `orders/show`, both turbo_stream templates |
| `orders/_product_browser` | `(order:, categories:, category:, products:)` | `orders/show` |
| `tables/_table` | `(spot:, order: nil)` | `tables/index` |
| `takeouts/_order_card` | `(order:)` | `takeouts/index` |
| `admin/shared/_nav` | `()` | 15 admin views |

Two partials read `local_assigns` and now read the declared local directly:

- `_line_item.html.erb`: `local_assigns[:highlight]` became `highlight`, declared `false`. Only `create.turbo_stream.erb` passes `true`.
- `_line_item_card.html.erb`: `local_assigns[:oldest_cooking_id]` became `oldest_cooking_id`, declared `nil`.

`tables/_table` also dropped a `defined?(order)` guard. With strict locals the local is always defined, so `if order && ...` is the honest check.

## Notes for next time

- **No model-callback partial renders exist in this app.** Every broadcast in `Order::Stateful` and `LineItem::Stateful` is `broadcast_refresh_to`, which is Turbo Morph and re-requests the page. Nothing renders a partial from a callback, so there were no background-job render paths to worry about. (An earlier draft of this plan assumed otherwise. Verified by grepping every `broadcast` call.)
- **No partial used instance variables.** Verified across all 11 before converting.
- Enforcement works under `Herb::Engine`, which matters because `intercept_erb` is on in test. Verified directly with `ApplicationController.render`:
  - omitting a required local raises `ActionView::Template::Error: missing local: :order`
  - passing an undeclared local raises `unknown local: :bogus`
  - omitting a local that has a default renders fine
- Controller tests were not sufficient to prove this. `takeouts_controller_test` passes even with `order:` deleted from the render call, because no fixture gives that store a takeout order, so the partial never renders. Both branches of every optional local were exercised with a direct render script instead.

## Verified

- `bundle exec herb lint`: 56 files, 0 offenses, 90 rules enabled.
- `bundle exec herb lint --all-rules`: only the deliberate `a11y-no-autofocus-attribute` on the bill view, which is excluded in `.herb.yml`.
- `bin/rails test`: 199 runs, 0 failures. `bin/rails test:system`: 92 runs, 0 failures.
