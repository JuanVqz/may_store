# Strict locals for the remaining 11 partials

## Why

`erb-strict-locals-required` is the last Herb rule with real offenses that we have not opted into. Rails strict locals (`<%# locals: (order:, highlight: false) %>`) turn a partial's implicit contract into a declared one: a caller that forgets a local, or passes one the partial does not use, fails loudly instead of rendering `nil` into the page.

The admin views already do this (18 partials declare strict locals, which is why `actionview-strict-locals-first-line` had 18 offenses to autocorrect). The older order/kitchen/table partials do not.

This is deliberately **not** part of the ReActionView adoption PR. Adopting the linter is reversible and touches nothing. Changing 11 partial contracts is a behavior change at every call site, and belongs in its own reviewable PR.

## Partials to convert

- `app/views/line_items/_customization_form.html.erb`
- `app/views/line_items/_line_item.html.erb`
- `app/views/kitchen/_line_item_card.html.erb`
- `app/views/orders/_closed.html.erb`
- `app/views/orders/_no_items_message.html.erb`
- `app/views/orders/_order_header.html.erb`
- `app/views/orders/_order_summary.html.erb`
- `app/views/orders/_product_browser.html.erb`
- `app/views/tables/_table.html.erb`
- `app/views/takeouts/_order_card.html.erb`
- `app/views/admin/shared/_nav.html.erb`

## Approach

One partial at a time:

1. Grep every call site, including Turbo Stream templates and broadcast calls in models. `LineItem` and `Order` broadcast partials from callbacks, so `render_to_string`-style call sites will not show up in a naive `render "line_items/line_item"` grep alone. Check `broadcast_*_to` arguments too.
2. Write the declaration with defaults for genuinely optional locals. `_line_item.html.erb` reads `local_assigns[:highlight]`, so that becomes `highlight: false`, not a required local.
3. Run `bin/rails test` and `bin/rails test:system`. A missing local raises at render time, so the system tests are the real safety net here.
4. Enable the rule in `.herb.yml` only after all 11 are done, so CI never sits red mid-migration.

## Watch out for

- **`local_assigns` usage disappears.** Once a partial declares strict locals, `local_assigns[:foo]` for an undeclared key is an error. Search each partial for `local_assigns` before converting.
- **Broadcast partials.** A partial rendered from a model callback fails in a background job, not a request. The failure surfaces as a missing Turbo Stream update rather than a 500, which is easy to miss by clicking around.
- **`actionview-strict-locals-first-line`** is already enabled, so each new declaration needs a blank line after it. `herb lint --fix` handles that.

## Done when

`bundle exec herb lint --all-rules` reports no `erb-strict-locals-required` offenses and the rule is enabled in `.herb.yml`.
