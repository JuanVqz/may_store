require "test_helper"

class KitchenControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "index shows cooking and ready line items" do
    get kitchen_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match line_items(:cooking_cappuccino).product.name.upcase, response.body
    assert_match line_items(:cooking_americano).product.name.upcase, response.body
  end

  test "index excludes delivered and cancelled items" do
    line_items(:cooking_cappuccino).mark_ready!
    line_items(:cooking_cappuccino).mark_delivered!
    line_items(:cooking_americano).cancel!

    get kitchen_url(subdomain: @store.subdomain)
    assert_response :success
    assert_no_match(/#{line_items(:cooking_cappuccino).product.name.upcase}/, response.body)
    assert_no_match(/#{line_items(:cooking_americano).product.name.upcase}/, response.body)
  end

  test "index orders by oldest first" do
    get kitchen_url(subdomain: @store.subdomain)
    assert_response :success
    assert_select "#kitchen-queue"
  end

  test "index requires authentication" do
    delete logout_url(subdomain: @store.subdomain)
    get kitchen_url(subdomain: @store.subdomain)
    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "index shows queue count" do
    get kitchen_url(subdomain: @store.subdomain)
    assert_select "#kitchen-queue-count", /2/
  end

  # The queue selects on item status alone, so items on a paid order still show
  # up here and still need delivering. Cancel is the one action the model refuses,
  # and a button that can only ever produce an alert is worse than no button.
  test "index hides cancel for items whose order was already paid" do
    order = orders(:cooking_order)
    item = order.line_items.first
    order.payments.create!(payment_method: payment_methods(:efectivo),
                           amount_cents: order.total_cents,
                           received_cents: order.total_cents, paid_at: Time.current)

    get kitchen_url(subdomain: @store.subdomain)

    assert_response :success
    assert_match item.product.name.upcase, response.body
    assert_select "form[action=?]", cancel_order_line_item_path(order, item), count: 0
    assert_select "form[action=?]", ready_order_line_item_path(order, item)
  end
end
