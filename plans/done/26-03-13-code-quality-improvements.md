# Code Quality Improvements

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix bugs, race conditions, and gaps found during code review — no new features, just correctness and robustness.

**Architecture:** Targeted fixes across models, controllers, and tests. Each task is independent.

**Tech Stack:** Ruby 3.4, Rails 8.1, Minitest, PostgreSQL

---

## Findings Summary

| # | Category | Severity | Description |
|---|----------|----------|-------------|
| 1 | Bug | High | `special_notes` from customization form is silently dropped |
| 2 | Bug | High | Race condition in `Order#generate_code` — concurrent orders can get duplicate codes |
| 3 | Bug | Medium | `Order#add_item!` accepts `components_params` but never uses them |
| 4 | Dead code | Low | `hello_controller.js` scaffold leftover |
| 5 | Test gap | Medium | No model tests for Category, Product, ProductComponent, Payment, PaymentMethod, CashClosing, OrderCounter, Table |

---

## Task 1: Fix `special_notes` Being Dropped

The customization form (`_customization_form.html.erb:58`) sends `special_notes` as a form field, but `LineItemsController#create` never reads it. Notes are silently lost.

**Files:**
- Modify: `app/controllers/line_items_controller.rb:16-28`
- Test: `test/controllers/line_items_controller_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# In line_items_controller_test.rb
test "create saves special_notes from customization form" do
  product = products(:americano)
  post order_line_items_path(@order), params: {
    line_item: { product_id: product.id },
    special_notes: "Sin hielo"
  }
  item = @order.line_items.last
  assert_equal "Sin hielo", item.special_notes
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/line_items_controller_test.rb -n test_create_saves_special_notes`
Expected: FAIL — `special_notes` is nil

- [ ] **Step 3: Fix `LineItemsController#create` to read `special_notes`**

In `app/controllers/line_items_controller.rb`, update the create action:

```ruby
def create
  product = Current.store.products.find(line_item_params[:product_id])
  notes = params[:special_notes].presence

  if @order.open?
    @line_item = @order.line_items.create!(
      product: product,
      status: :ordering,
      base_price_cents: product.base_price_cents,
      special_notes: notes
    )
  else
    @line_item = @order.add_item!(product: product, special_notes: notes)
  end

  build_components(@line_item, product)
  @line_item.calculate_total!
  @order.reload

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to order_path(@order), notice: t("order.item_added") }
  end
end
```

Also update `Order#add_item!` to actually use `special_notes`:

```ruby
def add_item!(product:, special_notes: nil)
  update!(status: :cooking) if ready? || delivered?

  item = line_items.create!(
    product: product,
    status: :cooking,
    base_price_cents: product.base_price_cents,
    special_notes: special_notes
  )
  item.calculate_total!
  item
end
```

Remove the unused `components_params` parameter from `add_item!` signature. Also update `docs/models.md` — search for `components_params` (appears twice, in the Order methods section and code example) and replace the signature with `add_item!(product:, special_notes: nil)` in both places.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/line_items_controller_test.rb -n test_create_saves_special_notes`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/line_items_controller.rb app/models/order.rb test/controllers/line_items_controller_test.rb
git commit -m "fix: save special_notes from customization form"
```

---

## Task 2: Fix Race Condition in `Order#generate_code`

`Order#generate_code` does `find_or_create_by!` + `update_all(increment)` + `reload`. Two concurrent requests can both read the same `current_sequence` before incrementing, producing duplicate codes. Fix with `RETURNING` or `WITH ... FOR UPDATE`.

**Files:**
- Modify: `app/models/order.rb:134-149`
- Test: `test/models/order_test.rb`

- [ ] **Step 1: Fix `generate_code` to use atomic SQL**

Replace the three-step pattern with a single atomic `UPDATE...RETURNING` query:

```ruby
def generate_code
  return if code.present?

  prefix = store.order_prefix
  year_month = Time.current.strftime("%y%m")

  begin
    OrderCounter.find_or_create_by!(store_id: store_id, year_month: year_month) do |c|
      c.current_sequence = 0
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  sql = OrderCounter.sanitize_sql_array([
    "UPDATE order_counters SET current_sequence = current_sequence + 1, updated_at = NOW() " \
    "WHERE store_id = ? AND year_month = ? RETURNING current_sequence",
    store_id, year_month
  ])
  seq = OrderCounter.connection.select_value(sql)

  self.code = "#{prefix}#{year_month}-#{seq.to_s.rjust(3, '0')}"
end
```

- [ ] **Step 2: Run full test suite to verify existing order code tests still pass**

Run: `bin/rails test`
Expected: All tests pass (existing `order_test.rb` already covers code generation and sequential numbering)

- [ ] **Step 3: Commit**

```bash
git add app/models/order.rb
git commit -m "fix: atomic sequence generation in Order#generate_code

Use UPDATE...RETURNING to prevent race condition where concurrent
order creation could produce duplicate codes."
```

---

## Task 3: Remove Dead Code

**Files:**
- Delete: `app/javascript/controllers/hello_controller.js`

- [ ] **Step 1: Verify `hello_controller` is unused**

Run: `grep -r "hello" app/views/ app/javascript/ --include="*.erb" --include="*.html" --include="*.js" | grep -v hello_controller.js`
Expected: No references

- [ ] **Step 2: Delete the file**

```bash
rm app/javascript/controllers/hello_controller.js
```

- [ ] **Step 3: Run test suite to confirm nothing breaks**

Run: `bin/rails test`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove unused hello_controller.js scaffold"
```

---

## Task 4: Add Missing Model Tests

Several models have zero test coverage. Add tests for the critical behaviors.

**Note:** Some tests reference fixtures that may not exist yet (e.g., `order_counters(:cafe_march)`, `cash_closings(:open_closing)`, `payments(:pago_efectivo)`). Check `test/fixtures/` and create any missing fixture entries before writing the tests. Also verify that `CashClosing` implements `total_expected_cents`, `total_actual_cents`, and `total_difference_cents` — if they're not defined, they'll need to be added to the model.

**Files:**
- Create: `test/models/category_test.rb`
- Create: `test/models/product_test.rb`
- Create: `test/models/product_component_test.rb`
- Create: `test/models/payment_test.rb`
- Create: `test/models/payment_method_test.rb`
- Create: `test/models/cash_closing_test.rb`
- Create: `test/models/order_counter_test.rb`
- Create: `test/models/table_test.rb`

### 4a: Category tests

- [ ] **Step 1: Write tests**

```ruby
# test/models/category_test.rb
require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "ordered scope sorts by position" do
    categories = Category.where(store: stores(:cafe_delicias)).ordered
    positions = categories.map(&:position).compact
    assert_equal positions.sort, positions
  end

  test "soft delete sets deleted_at" do
    category = categories(:bebidas_calientes)
    category.soft_delete!
    assert category.deleted?
    assert_not_nil category.deleted_at
  end

  test "active scope excludes soft-deleted" do
    category = categories(:bebidas_calientes)
    category.soft_delete!
    assert_not_includes Category.active, category
  end

  test "validates name presence" do
    category = Category.new(store: stores(:cafe_delicias))
    assert_not category.valid?
    assert_includes category.errors[:name], I18n.t("errors.messages.blank")
  end
end
```

- [ ] **Step 2: Run tests**

Run: `bin/rails test test/models/category_test.rb`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add test/models/category_test.rb
git commit -m "test: add Category model tests"
```

### 4b: Product tests

- [ ] **Step 4: Write tests**

```ruby
# test/models/product_test.rb
require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "available scope filters by available flag" do
    product = products(:americano)
    assert_includes Product.available, product

    product.update!(available: false)
    assert_not_includes Product.available, product
  end

  test "soft delete and restore" do
    product = products(:americano)
    product.soft_delete!
    assert product.deleted?
    assert_not_includes Product.active, product

    product.restore!
    assert_not product.deleted?
    assert_includes Product.active, product
  end

  test "price helpers from PriceCents" do
    product = products(:americano)
    assert_equal product.base_price_cents / 100.0, product.base_price
    assert product.formatted_base_price.start_with?("$")
  end

  test "belongs to store and category" do
    product = products(:americano)
    assert_not_nil product.store
    assert_not_nil product.category
  end
end
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/models/product_test.rb`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add test/models/product_test.rb
git commit -m "test: add Product model tests"
```

### 4c: Table tests

- [ ] **Step 7: Write tests**

```ruby
# test/models/table_test.rb
require "test_helper"

class TableTest < ActiveSupport::TestCase
  test "validates name uniqueness per store" do
    existing = tables(:mesa_1)
    duplicate = Table.new(store: existing.store, name: existing.name)
    assert_not duplicate.valid?
  end

  test "validates name presence" do
    table = Table.new(store: stores(:cafe_delicias))
    assert_not table.valid?
    assert_includes table.errors[:name], I18n.t("errors.messages.blank")
  end
end
```

- [ ] **Step 8: Run tests**

Run: `bin/rails test test/models/table_test.rb`
Expected: All pass

- [ ] **Step 9: Commit**

```bash
git add test/models/table_test.rb
git commit -m "test: add Table model tests"
```

### 4d: Payment and PaymentMethod tests

- [ ] **Step 10: Write tests**

```ruby
# test/models/payment_test.rb
require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "validates amount_cents is positive" do
    payment = Payment.new(
      order: orders(:order_delivered),
      payment_method: payment_methods(:efectivo),
      amount_cents: 0
    )
    assert_not payment.valid?
  end

  test "price helpers from PriceCents" do
    payment = payments(:pago_efectivo)
    assert payment.formatted_amount.start_with?("$")
  end
end
```

```ruby
# test/models/payment_method_test.rb
require "test_helper"

class PaymentMethodTest < ActiveSupport::TestCase
  test "active scope returns only active methods" do
    method = payment_methods(:efectivo)
    assert_includes PaymentMethod.active, method

    method.update!(active: false)
    assert_not_includes PaymentMethod.active, method
  end
end
```

- [ ] **Step 11: Run tests**

Run: `bin/rails test test/models/payment_test.rb test/models/payment_method_test.rb`
Expected: All pass

- [ ] **Step 12: Commit**

```bash
git add test/models/payment_test.rb test/models/payment_method_test.rb
git commit -m "test: add Payment and PaymentMethod model tests"
```

### 4e: OrderCounter and CashClosing tests

- [ ] **Step 13: Write tests**

```ruby
# test/models/order_counter_test.rb
require "test_helper"

class OrderCounterTest < ActiveSupport::TestCase
  test "unique constraint on store_id + year_month" do
    existing = order_counters(:cafe_march)
    duplicate = OrderCounter.new(
      store: existing.store,
      year_month: existing.year_month,
      current_sequence: 0
    )
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
```

```ruby
# test/models/cash_closing_test.rb
require "test_helper"

class CashClosingTest < ActiveSupport::TestCase
  test "status enum" do
    closing = cash_closings(:open_closing)
    assert closing.open?
    closing.update!(status: :closed, closed_at: Time.current)
    assert closing.closed?
  end

  test "total helpers sum from cash_closing_lines" do
    closing = cash_closings(:open_closing)
    expected_sum = closing.cash_closing_lines.sum(:expected_cents)
    assert_equal expected_sum, closing.total_expected_cents

    actual_sum = closing.cash_closing_lines.sum(:actual_cents)
    assert_equal actual_sum, closing.total_actual_cents

    diff_sum = closing.cash_closing_lines.sum(:difference_cents)
    assert_equal diff_sum, closing.total_difference_cents
  end
end
```

- [ ] **Step 14: Run tests**

Run: `bin/rails test test/models/order_counter_test.rb test/models/cash_closing_test.rb`
Expected: All pass

- [ ] **Step 15: Commit**

```bash
git add test/models/order_counter_test.rb test/models/cash_closing_test.rb
git commit -m "test: add OrderCounter and CashClosing model tests"
```

### 4f: ProductComponent tests

- [ ] **Step 16: Write tests**

```ruby
# test/models/product_component_test.rb
require "test_helper"

class ProductComponentTest < ActiveSupport::TestCase
  test "component_type enum" do
    pc = product_components(:americano_espresso)
    assert pc.ingredient? || pc.extra?
  end

  test "ordered scope sorts by position" do
    product = products(:americano)
    pcs = product.product_components.ordered
    positions = pcs.map(&:position).compact
    assert_equal positions.sort, positions
  end
end
```

- [ ] **Step 17: Run tests**

Run: `bin/rails test test/models/product_component_test.rb`
Expected: All pass

- [ ] **Step 18: Commit**

```bash
git add test/models/product_component_test.rb
git commit -m "test: add ProductComponent model tests"
```

---

## Done When

- `special_notes` from customization form is persisted on line items
- `Order#generate_code` uses atomic SQL (no TOCTOU race)
- `hello_controller.js` removed
- All models have at least basic test coverage
- Full test suite passes: `bin/rails test`
