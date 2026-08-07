# System Tests Setup

Set up browser driver (Capybara + Selenium/Cuprite) for system tests. Write system tests for interactive UI flows like product customization (Stimulus), real-time Turbo Stream updates, and full order lifecycle.

## Outcome

Done. 92 system tests across 8 files, plus supporting model and integration tests.

- [x] Browser driver. Kept Selenium + headless Chrome (already configured in `ApplicationSystemTestCase`) rather than switching to Cuprite, since CI already installs `google-chrome-stable` and uploads failure screenshots.
- [x] Subdomain multitenancy in the browser. The app resolves the store from the subdomain, so tests cannot browse `127.0.0.1`. Chrome is started with `--host-resolver-rules=MAP * 127.0.0.1`, so `cafe-delicias.example.com` reaches the Capybara server identically on a laptop and on CI, with no `/etc/hosts` edits and without depending on `*.localhost` resolution.
- [x] Product customization (Stimulus): portion buttons, required vs optional ingredients, extra counters, special notes.
- [x] Turbo Stream updates: adding and removing line items, order summary and header refresh.
- [x] Full order lifecycle: open, build, confirm, cook, ready, deliver, bill, close, plus cancellation.
- [x] Kitchen queue: grouping, ordering, ready/cancel/deliver, empty state, takeout labelling.
- [x] Billing: cash with change, non-cash, underpayment rejection, terminal closed orders.
- [x] Admin CRUD across categories, ingredients, products, spots, payment methods, including validation and soft delete.
- [x] Multitenancy isolation: same employee number in two stores, cross-store data and URL access.

## Coverage

| File | Tests |
|---|---|
| `test/system/authentication_test.rb` | 9 |
| `test/system/order_flow_test.rb` | 17 |
| `test/system/kitchen_test.rb` | 13 |
| `test/system/billing_test.rb` | 12 |
| `test/system/takeout_test.rb` | 7 |
| `test/system/orders_today_test.rb` | 6 |
| `test/system/admin_catalog_test.rb` | 20 |
| `test/system/multitenancy_test.rb` | 8 |

## Bugs these tests found

Writing them surfaced six real defects, all fixed in the same PR:

1. **Login flash never rendered.** `layouts/login.html.erb` passed `toast_flash_messages` to the toaster component as a block, but the component takes a `content:` local and never yields. Every flash on the login page was silently dropped, so a wrong password gave the user no feedback at all.
2. **Removing the last line item left a blank list.** `create.turbo_stream.erb` removed `no_items_message` but `destroy.turbo_stream.erb` never restored it.
3. **Deleting a spot with orders returned a 500.** `ActiveRecord::InvalidForeignKey` escaped the admin controller. Now `dependent: :restrict_with_error` on the model.
4. **Deleting a payment method with payments returned a 500.** Same cause, same fix.
5. **Duplicate `admin:` key in `es.yml`.** YAML kept only the second block, so eight keys resolved to `nil`.
6. **English leaked into the Spanish UI.** A missing `received_cents` attribute translation produced "Received cents debe ser mayor o igual a $45.00".

## Note on test layering

The login flash message is asserted in `test/integration/login_flash_test.rb`, not in a system test. The toast auto-dismisses after five seconds, which makes a browser assertion racy under parallel load (it failed exactly that way before being moved). The bug was in server-rendered HTML, so the request level is both the precise and the deterministic place to guard it. The system test asserts the durable browser behaviour instead: the attempt is refused and the user stays on the login page.
