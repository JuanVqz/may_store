require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  test "calculate_total adds base price and extras" do
    order = orders(:open_order)
    product = products(:cappuccino)
    item = LineItem.create!(order: order, product: product, status: :ordering, base_price_cents: 4500)

    LineItemComponent.create!(line_item: item, component: components(:extra_chocolate), component_type: :extra, portion: 1.0, unit_price_cents: 1000)
    LineItemComponent.create!(line_item: item, component: components(:extra_chocolate), component_type: :extra, portion: 1.0, unit_price_cents: 1000)

    item.calculate_total!
    assert_equal 6500, item.total_price_cents
  end

  test "mark_ready changes status" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    assert_equal "ready", item.status
  end

  test "mark_ready tracks who marked it ready" do
    user = users(:waiter_juan)
    item = line_items(:cooking_cappuccino)
    item.mark_ready!(by: user)
    assert_equal user, item.ready_by
  end

  test "cancel changes status" do
    item = line_items(:cooking_americano)
    item.cancel!
    assert_equal "cancelled", item.status
  end

  # The bill reads order.total_cents, so a cancelled item that never triggers a
  # recalculation is still charged for at the register.
  test "cancel drops the item from the order total" do
    item = line_items(:cooking_americano)
    order = item.order
    order.recalculate_total!
    before = order.total_cents

    item.cancel!

    assert_equal before - item.total_price_cents, order.reload.total_cents
  end

  test "cancel tracks who cancelled it" do
    user = users(:waiter_juan)
    item = line_items(:cooking_americano)
    item.cancel!(by: user)
    assert_equal user, item.cancelled_by
  end

  test "mark_delivered tracks who delivered it" do
    user = users(:waiter_juan)
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    item.mark_delivered!(by: user)
    assert_equal "delivered", item.status
    assert_equal user, item.delivered_by
  end

  test "status callbacks trigger order status check" do
    order = orders(:cooking_order)
    line_items(:cooking_cappuccino).mark_ready!
    line_items(:cooking_americano).mark_ready!
    assert_equal "ready", order.reload.status
  end

  test "recalculates order total on save" do
    order = orders(:open_order)
    item = line_items(:ordering_americano)
    item.update!(total_price_cents: 5000)
    assert_equal 5000, order.reload.total_cents
  end

  test "price_in_cents helpers" do
    item = line_items(:cooking_cappuccino)
    assert_equal 45.0, item.base_price
    assert_equal "$45.00", item.formatted_base_price
  end

  # Status transition guards
  test "mark_ready raises on non-cooking item" do
    item = line_items(:ordering_americano)
    assert_raises(LineItem::InvalidTransition) { item.mark_ready! }
  end

  test "mark_ready raises on already ready item" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    assert_raises(LineItem::InvalidTransition) { item.mark_ready! }
  end

  test "mark_delivered raises on cooking item" do
    item = line_items(:cooking_cappuccino)
    assert_raises(LineItem::InvalidTransition) { item.mark_delivered! }
  end

  test "cancel raises on delivered item" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    item.mark_delivered!
    assert_raises(LineItem::InvalidTransition) { item.cancel! }
  end

  test "cancel raises on already cancelled item" do
    item = line_items(:cooking_americano)
    item.cancel!
    assert_raises(LineItem::InvalidTransition) { item.cancel! }
  end

  # Reachable whenever the bill is settled before the food goes out: the order is
  # closed while its items are still READY. Cancelling one then would drop the
  # order total below what was already paid. The item has to be genuinely
  # cancellable for this to reach the order guard at all, so it is left READY
  # instead of reusing a delivered fixture the status check already rejects.
  test "cancel! refuses a ready item on a closed order" do
    order = orders(:cooking_order)
    order.line_items.each { |li| li.mark_ready!(by: users(:waiter_juan)) }
    item = order.line_items.first
    pay_in_full(order)
    order.close!

    assert_raises LineItem::Stateful::OrderPaid do
      item.reload.cancel!(by: users(:waiter_juan))
    end

    assert_not item.reload.cancelled?
    assert_equal order.total_cents, order.reload.total_cents
  end

  test "cancel! refuses a ready item once the order was paid, before it is closed" do
    order = orders(:cooking_order)
    order.line_items.each { |li| li.mark_ready!(by: users(:waiter_juan)) }
    item = order.line_items.first
    pay_in_full(order)

    assert_not order.reload.closed?
    assert_raises LineItem::Stateful::OrderPaid do
      item.reload.cancel!(by: users(:waiter_juan))
    end
    assert_equal order.total_cents, order.reload.total_cents
  end

  # The item's own status is the more precise reason, so it wins even when the
  # order has also been paid.
  test "cancel! blames the item status, not the payment, for a delivered item" do
    order = orders(:cooking_order)
    order.line_items.each { |li| li.mark_ready!(by: users(:waiter_juan)) }
    item = order.line_items.first
    item.reload.mark_delivered!(by: users(:waiter_juan))
    pay_in_full(order)

    error = assert_raises LineItem::Stateful::InvalidTransition do
      item.reload.cancel!(by: users(:waiter_juan))
    end
    assert_not_kind_of LineItem::Stateful::OrderPaid, error
  end

  # cancellable? is what the views ask; cancel! is what enforces. If they drift, a
  # button appears that the model then refuses, or one disappears that would have
  # worked, so each refusal is checked from both sides.
  test "cancellable? agrees with cancel! on every refusal" do
    order = orders(:cooking_order)
    order.line_items.each { |li| li.mark_ready!(by: users(:waiter_juan)) }
    ready = line_items(:cooking_cappuccino).reload

    assert ready.cancellable?

    delivered = line_items(:cooking_americano).reload
    delivered.mark_delivered!(by: users(:waiter_juan))
    assert_not delivered.cancellable?
    assert_raises(LineItem::Stateful::InvalidTransition) { delivered.cancel! }

    pay_in_full(order)
    assert_not ready.reload.cancellable?
    assert_raises(LineItem::Stateful::OrderPaid) { ready.cancel! }
  end

  private

  def pay_in_full(order)
    order.reload.payments.create!(payment_method: payment_methods(:efectivo),
                                  amount_cents: order.total_cents,
                                  received_cents: order.total_cents, paid_at: Time.current)
  end

  # One tap has to keep working, so cancelling with no reason given must still
  # record something usable.
  test "cancel! records the default reason when none is given" do
    item = line_items(:cooking_cappuccino)

    item.cancel!(by: users(:waiter_juan))

    assert_equal LineItem::DEFAULT_CANCELLATION_REASON, item.reload.cancellation_reason
    assert item.reason_customer_changed_mind?
  end

  test "cancel! records an explicit reason instead" do
    item = line_items(:cooking_cappuccino)

    item.cancel!(by: users(:kitchen_carlos), reason: "kitchen_error")

    assert_equal "kitchen_error", item.reload.cancellation_reason
  end

  # A stale or tampered form post must fail validation rather than raise
  # ArgumentError on assignment and turn into a 500.
  test "an unknown reason fails validation instead of raising" do
    item = line_items(:cooking_cappuccino)

    item.cancellation_reason = "because_i_said_so"

    assert_not item.valid?
    assert_includes item.errors.attribute_names, :cancellation_reason
  end

  # Items cancelled before reasons existed have none, and that has to stay legal.
  test "no reason at all is a valid state" do
    item = line_items(:cooking_cappuccino)
    item.update_columns(status: "cancelled", cancellation_reason: nil)

    assert item.reload.valid?
    assert_nil item.cancellation_reason_label
  end

  test "the reason reads back as Spanish" do
    item = line_items(:cooking_cappuccino)
    item.cancel!(reason: "out_of_stock")

    assert_equal I18n.t("cancellation_reasons.out_of_stock"), item.cancellation_reason_label
  end

  # The kitchen screen is this scope. An item still on a draft order has not
  # been sent yet, and a delivered or cancelled one is off the pass.
  test "on_the_pass holds only the items the kitchen still owes" do
    on_the_pass = LineItem.on_the_pass

    assert_includes on_the_pass, line_items(:cooking_cappuccino)
    assert_not_includes on_the_pass, line_items(:ordering_americano)
    assert_not_includes on_the_pass, line_items(:delivered_latte)
  end

  test "in_store keeps another store's items off the queue" do
    other_store = stores(:mi_cafe)
    category = other_store.categories.create!(name: "Bebidas", station: :bar, position: 1)
    product = other_store.products.create!(category: category, name: "Cafe", base_price_cents: 1000, available: true)
    order = other_store.orders.create!(
      spot: other_store.spots.create!(name: "Mesa 1", spot_type: :dine_in, position: 1, active: true),
      user: users(:other_store_waiter), status: :cooking, opened_at: Time.current
    )
    foreign_item = order.line_items.create!(product: product, status: :cooking, base_price_cents: 1000)

    items = LineItem.in_store(stores(:cafe_delicias)).on_the_pass

    assert_includes items, line_items(:cooking_cappuccino)
    assert_not_includes items, foreign_item
  end
end
