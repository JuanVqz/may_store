require "test_helper"

class KitchenTicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @order = orders(:cooking_order)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "KIT-001", password: "password123" }
  end

  test "show streams the whole order's ticket as ESC/POS bytes" do
    get order_kitchen_ticket_url(@order, subdomain: @store.subdomain)

    assert_response :success
    assert_equal "application/vnd.escpos", response.media_type
    assert_includes response.body, @order.code
    assert_includes response.body, @order.line_items.first.product.name.upcase
  end

  test "station narrows the ticket to one prep area" do
    @order.add_item!(product: products(:crepa_nutella))

    get order_kitchen_ticket_url(@order, station: "kitchen", subdomain: @store.subdomain)

    assert_response :success
    assert_includes response.body, "CREPA DE NUTELLA"
    assert_not_includes response.body, "CAPPUCCINO CARAMEL"
  end

  # A typo'd or tampered station would otherwise print a blank ticket, which the
  # cook reads as "no items" rather than "bad link".
  test "an unknown station falls back to the whole order" do
    get order_kitchen_ticket_url(@order, station: "nowhere", subdomain: @store.subdomain)

    assert_response :success
    assert_includes response.body, @order.line_items.first.product.name.upcase
  end

  test "show requires authentication" do
    delete logout_url(subdomain: @store.subdomain)

    get order_kitchen_ticket_url(@order, subdomain: @store.subdomain)

    assert_redirected_to login_url(subdomain: @store.subdomain)
  end
end
