require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @store = stores(:cafe_delicias)
    @spot = spots(:mesa_5)
    @user = users(:waiter_juan)
    @product = products(:americano)
  end

  test "generates code on create" do
    order = Order.create!(store: @store, spot: @spot, user: @user, status: :open)
    assert_match(/\ACFE\d{4}-\d{3}\z/, order.code)
  end

  test "increments sequence for same store and month" do
    order1 = Order.create!(store: @store, spot: @spot, user: @user, status: :open)
    order2 = Order.create!(store: @store, spot: @spot, user: @user, status: :open)

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

  test "close sets closed status when fully paid" do
    order = orders(:cooking_order)
    order.update_columns(total_cents: 5000)
    Payment.create!(order: order, payment_method: payment_methods(:efectivo), amount_cents: 5000, received_cents: 5000, paid_at: Time.current)

    order.close!
    assert_equal "closed", order.status
    assert_not_nil order.closed_at
  end

  test "close raises when not fully paid" do
    order = orders(:cooking_order)
    order.update_columns(total_cents: 5000)

    assert_raises(ActiveRecord::RecordInvalid) { order.close! }
  end

  test "add_item to ready order sets it back to cooking" do
    order = orders(:cooking_order)
    line_items(:cooking_cappuccino).mark_ready!
    line_items(:cooking_americano).mark_ready!
    assert_equal "ready", order.reload.status

    order.add_item!(product: @product)
    assert_equal "cooking", order.reload.status
  end

  # The status the new item starts in is what decides whether the kitchen sees
  # it now or when the order is confirmed.
  test "add_item on an order still being taken leaves the item in the draft" do
    order = orders(:open_order)

    item = order.add_item!(product: @product)

    assert item.ordering?
    assert order.reload.open?
  end

  test "add_item on a cooking order sends the item straight to the kitchen" do
    order = orders(:cooking_order)

    item = order.add_item!(product: @product)

    assert item.cooking?
  end

  test "add_item prices the extras it was given" do
    order = orders(:open_order)
    chocolate = components(:extra_chocolate)

    item = order.add_item!(product: products(:cappuccino), extras: { chocolate.id.to_s => "1" })

    assert_equal products(:cappuccino).base_price_cents + chocolate.price_cents, item.total_price_cents
    assert_equal order.line_items.not_cancelled.sum(:total_price_cents), order.reload.total_cents
  end

  test "payment tracking" do
    order = orders(:cooking_order)
    order.update_columns(total_cents: 8000)

    Payment.create!(order: order, payment_method: payment_methods(:efectivo), amount_cents: 5000, received_cents: 5000, paid_at: Time.current)
    assert_equal 5000, order.total_paid_cents
    assert_equal 3000, order.remaining_cents
    assert_not order.fully_paid?

    Payment.create!(order: order, payment_method: payment_methods(:mercado_pago), amount_cents: 3000, received_cents: 3000, paid_at: Time.current)
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

  test "readiness_counts returns ready and total counts" do
    order = orders(:cooking_order)
    counts = order.readiness_counts
    assert_equal 0, counts[:ready]
    assert_equal 2, counts[:total]

    line_items(:cooking_cappuccino).mark_ready!
    counts = order.readiness_counts
    assert_equal 1, counts[:ready]
    assert_equal 2, counts[:total]
  end

  test "readiness_counts excludes cancelled items" do
    order = orders(:cooking_order)
    line_items(:cooking_americano).cancel!
    counts = order.readiness_counts
    assert_equal 0, counts[:ready]
    assert_equal 1, counts[:total]
  end

  test "today scope includes orders created today" do
    order = Order.create!(store: @store, spot: @spot, user: @user, status: :open)
    assert_includes @store.orders.today, order
  end

  test "today scope excludes orders from other days" do
    order = Order.create!(store: @store, spot: @spot, user: @user, status: :open, created_at: 1.day.ago)
    assert_not_includes @store.orders.today, order
  end

  # A closed order has been paid in full. Cancelling it would void a settled sale
  # and free the table while the money stays in the drawer, and nothing in the app
  # can hand that money back.
  test "cancel! refuses a closed order" do
    order = orders(:delivered_order)
    order.payments.create!(payment_method: payment_methods(:efectivo),
                           amount_cents: order.total_cents,
                           received_cents: order.total_cents, paid_at: Time.current)
    order.close!

    assert_not order.cancel!
    assert order.reload.closed?
    assert_nil order.cancelled_at
  end

  # The money, not the status, is what makes cancelling wrong. A payment row
  # exists before close! runs, and cancelling in that window strands the same
  # cash as cancelling a closed order does.
  test "cancel! refuses an order that was paid but not closed yet" do
    order = orders(:delivered_order)
    order.payments.create!(payment_method: payment_methods(:efectivo),
                           amount_cents: order.total_cents,
                           received_cents: order.total_cents, paid_at: Time.current)

    assert_not order.reload.closed?
    assert_not order.cancel!
    assert_not order.reload.cancelled?
    assert_nil order.cancelled_at
  end

  test "cancel! still cancels an unpaid order and its outstanding items" do
    order = orders(:cooking_order)

    assert order.cancel!
    assert order.reload.cancelled?
    assert_empty order.line_items.where(status: [:ordering, :cooking, :ready])
  end

  # An empty order owes nothing, so fully_paid? is true for it. Guarding cancel
  # on that instead of on payment_taken? would leave a freshly opened order
  # impossible to cancel, which is why the two predicates stay separate.
  test "cancel! still cancels an empty order nobody has paid" do
    order = Order.create!(store: @store, spot: @spot, user: @user, status: :open)

    assert order.fully_paid?
    assert_not order.payment_taken?
    assert order.cancel!
    assert order.reload.cancelled?
  end

  # Cancelling a whole order cascades with update_all, which bypasses
  # LineItem#cancel!. Without this the cascade would be the only path leaving a
  # cancelled item with no reason, making "nobody said" and "cancelled with the
  # order" indistinguishable.
  test "cancelling an order records a reason on the items it cancels" do
    order = orders(:cooking_order)

    order.cancel!

    order.line_items.reload.each do |item|
      assert item.cancelled?
      assert_equal LineItem::DEFAULT_CANCELLATION_REASON, item.cancellation_reason
    end
  end
end
