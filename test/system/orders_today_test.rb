require "application_system_test_case"

class OrdersTodayTest < ApplicationSystemTestCase
  setup do
    sign_in_waiter

    # Fixtures are inserted once, at the start of the run, so a suite that crosses
    # midnight leaves them stamped yesterday and Order.today drops them: this file
    # failed at 00:00:59 local for a scope that was behaving correctly. Restamping
    # them here ties "today" to the moment the test runs instead of to whenever
    # the fixtures were loaded.
    Order.update_all(created_at: Time.current)
  end

  test "today's orders lists both table and takeout orders" do
    takeout = Order.create!(
      store: stores(:cafe_delicias),
      spot: spots(:para_llevar),
      user: users(:waiter_juan),
      status: :open,
      opened_at: Time.current
    )

    visit orders_path

    assert_text orders(:open_order).code
    assert_text orders(:cooking_order).code
    assert_text takeout.code
  end

  test "each order shows its spot, status and total" do
    order = orders(:cooking_order)

    visit orders_path

    assert_text order.spot.name
    assert_text order.status_label
    assert_text order.formatted_total
  end

  test "orders from previous days are excluded" do
    orders(:open_order).update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)

    visit orders_path

    assert_no_text orders(:open_order).code
  end

  test "an order links through to its detail screen" do
    order = orders(:cooking_order)

    visit orders_path
    click_on order.code

    assert_current_path order_path(order)
  end

  test "the empty state shows when nothing was opened today" do
    Order.update_all(created_at: 3.days.ago)

    visit orders_path

    assert_text I18n.t("orders_today.no_orders")
  end

  test "orders from another store are never listed" do
    other = Order.create!(
      store: stores(:mi_cafe),
      spot: Spot.create!(store: stores(:mi_cafe), name: "Mesa Uno", spot_type: :dine_in, position: 1, active: true),
      user: users(:other_store_waiter),
      status: :open,
      opened_at: Time.current
    )

    visit orders_path

    assert_no_text other.code
  end
end
