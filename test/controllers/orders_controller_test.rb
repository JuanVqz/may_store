require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "new creates order and redirects to products" do
    table = tables(:mesa_1)
    assert_difference "Order.count", 1 do
      get new_table_order_url(table, subdomain: @store.subdomain)
    end
    order = Order.last
    assert_equal "open", order.status
    assert_redirected_to order_products_url(order, subdomain: @store.subdomain)
  end

  test "show displays order" do
    order = orders(:open_order)
    get order_url(order, subdomain: @store.subdomain)
    assert_response :success
    assert_match order.code, response.body
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
