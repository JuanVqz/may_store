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
end
