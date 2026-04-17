require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "create creates order and redirects to order show" do
    spot = spots(:mesa_1)
    assert_difference "Order.count", 1 do
      post spot_orders_url(spot, subdomain: @store.subdomain)
    end
    order = @store.orders.order(created_at: :desc).first
    assert_equal "open", order.status
    assert_redirected_to order_url(order, subdomain: @store.subdomain)
  end

  test "bill shows bill page with items and payment methods" do
    order = orders(:delivered_order)
    get bill_order_url(order, subdomain: @store.subdomain)
    assert_response :success
    assert_match "Cuenta", response.body
    assert_match "Efectivo", response.body
    assert_match "Mercado Pago", response.body
    assert_match "Transferencia", response.body
  end

  test "bill shows cancelled items as cancelado" do
    order = orders(:cooking_order)
    line_items(:cooking_cappuccino).cancel!
    get bill_order_url(order, subdomain: @store.subdomain)
    assert_response :success
    assert_match "CANCELADO", response.body
  end

  test "show displays closed view when order is closed" do
    order = orders(:delivered_order)
    order.update_columns(total_cents: 5000)
    Payment.create!(order: order, payment_method: payment_methods(:efectivo), amount_cents: 5000, paid_at: Time.current)
    order.close!

    get order_url(order, subdomain: @store.subdomain)
    assert_response :success
    assert_match "Orden Cerrada", response.body
    assert_match "Volver a Mesas", response.body
  end

  test "show displays product browser for open order" do
    order = orders(:open_order)
    get order_url(order, subdomain: @store.subdomain)
    assert_response :success
    assert_match order.code, response.body
    # Product browser is visible
    assert_match "product_browser", response.body
    assert_match "Bebidas Calientes", response.body
  end

  test "show displays product browser with category filter" do
    order = orders(:open_order)
    category = categories(:bebidas_calientes)
    get order_url(order, subdomain: @store.subdomain, category_id: category.id)
    assert_response :success
    # Selected category tab is active
    assert_match category.name, response.body
  end

  test "show displays product browser for cooking order" do
    order = orders(:cooking_order)
    get order_url(order, subdomain: @store.subdomain)
    assert_response :success
    assert_match order.code, response.body
    assert_match "product_browser", response.body
    assert_match "Bebidas Calientes", response.body
  end

  test "show displays line items with action buttons" do
    order = orders(:cooking_order)
    get order_url(order, subdomain: @store.subdomain)
    assert_response :success
    assert_match I18n.t("kitchen.ready"), response.body
  end

  test "confirm with no items redirects with alert" do
    spot = spots(:mesa_1)
    post spot_orders_url(spot, subdomain: @store.subdomain)
    order = @store.orders.order(created_at: :desc).first
    patch confirm_order_url(order, subdomain: @store.subdomain)
    assert_equal "open", order.reload.status
    assert_redirected_to order_url(order, subdomain: @store.subdomain)
  end

  test "confirm transitions order to cooking" do
    order = orders(:open_order)
    patch confirm_order_url(order, subdomain: @store.subdomain)
    assert_equal "cooking", order.reload.status
    assert_redirected_to order_url(order, subdomain: @store.subdomain)
  end

  test "cancel transitions order to cancelled" do
    order = orders(:cooking_order)
    patch cancel_order_url(order, subdomain: @store.subdomain)
    assert_equal "cancelled", order.reload.status
    assert_redirected_to tables_url(subdomain: @store.subdomain)
  end
end
