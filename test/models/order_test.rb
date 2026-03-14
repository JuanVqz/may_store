require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @store = stores(:cafe_delicias)
    @table = tables(:mesa_5)
    @user = users(:waiter_juan)
    @product = products(:americano)
  end

  test "generates code on create" do
    order = Order.create!(store: @store, table: @table, user: @user, status: :open)
    assert_match(/\ACFE\d{4}-\d{3}\z/, order.code)
  end

  test "increments sequence for same store and month" do
    order1 = Order.create!(store: @store, table: @table, user: @user, status: :open)
    order2 = Order.create!(store: @store, table: @table, user: @user, status: :open)

    seq1 = order1.code.split("-").last.to_i
    seq2 = order2.code.split("-").last.to_i
    assert_equal seq1 + 1, seq2
  end

  test "confirm transitions order and items to cooking" do
    order = orders(:open_order)
    item = line_items(:ordering_americano)
    assert_equal "ordering", item.status

    order.confirm!
    assert_equal "cooking", order.reload.status
    assert_equal "cooking", item.reload.status
    assert_not_nil order.cooking_at
  end

  test "check_ready transitions when all items ready or cancelled" do
    order = orders(:cooking_order)
    line_items(:cooking_cappuccino).mark_ready!
    line_items(:cooking_americano).cancel!

    assert_equal "ready", order.reload.status
  end

  test "check_delivered transitions when all items delivered or cancelled" do
    order = orders(:cooking_order)
    line_items(:cooking_cappuccino).mark_ready!
    line_items(:cooking_americano).mark_ready!
    order.reload

    line_items(:cooking_cappuccino).mark_delivered!
    line_items(:cooking_americano).mark_delivered!

    assert_equal "delivered", order.reload.status
  end

  test "cancel cancels order and non-delivered items" do
    order = orders(:cooking_order)
    order.cancel!

    assert_equal "cancelled", order.reload.status
    assert order.line_items.all? { |li| li.reload.cancelled? }
  end

  test "recalculate_total sums non-cancelled items" do
    order = orders(:cooking_order)
    order.recalculate_total!
    assert_equal 8000, order.total_cents
  end

  test "close sets closed status" do
    order = orders(:cooking_order)
    order.close!
    assert_equal "closed", order.status
    assert_not_nil order.closed_at
  end

  test "add_item to ready order sets it back to cooking" do
    order = orders(:cooking_order)
    line_items(:cooking_cappuccino).mark_ready!
    line_items(:cooking_americano).mark_ready!
    assert_equal "ready", order.reload.status

    order.add_item!(product: @product)
    assert_equal "cooking", order.reload.status
  end

  test "payment tracking" do
    order = orders(:cooking_order)
    order.update_columns(total_cents: 8000)

    Payment.create!(order: order, payment_method: payment_methods(:efectivo), amount_cents: 5000, paid_at: Time.current)
    assert_equal 5000, order.total_paid_cents
    assert_equal 3000, order.remaining_cents
    assert_not order.fully_paid?

    Payment.create!(order: order, payment_method: payment_methods(:tarjeta), amount_cents: 3000, paid_at: Time.current)
    assert order.fully_paid?
  end

  test "cancelling all items cancels the order" do
    order = orders(:cooking_order)
    line_items(:cooking_cappuccino).cancel!
    line_items(:cooking_americano).cancel!

    assert_equal "cancelled", order.reload.status
  end

  test "price_in_cents helpers" do
    order = orders(:cooking_order)
    order.update_columns(total_cents: 8000)
    assert_equal 80.0, order.total
    assert_equal "$80.00", order.formatted_total
  end
end
