require "test_helper"

class ReceiptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @order = orders(:cooking_order)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "show streams the bill as ESC/POS bytes" do
    get order_receipt_url(@order, subdomain: @store.subdomain)

    assert_response :success
    assert_equal "application/vnd.escpos", response.media_type
    assert response.body.start_with?("\e@")
    assert_includes response.body, @order.code
  end

  # How development looks at a receipt without feeding paper through the printer.
  test "the txt format renders a readable preview instead of bytes" do
    get order_receipt_url(@order, format: :txt, subdomain: @store.subdomain)

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_includes response.body, @order.code
    assert_not_includes response.body, "\e@"
  end

  test "show requires authentication" do
    delete logout_url(subdomain: @store.subdomain)

    get order_receipt_url(@order, subdomain: @store.subdomain)

    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "show cannot reach another store's order" do
    other_store = stores(:mi_cafe)
    other_order = other_store.orders.create!(
      spot: other_store.spots.create!(name: "Mesa 1", spot_type: :dine_in, position: 1, active: true),
      user: users(:other_store_waiter),
      status: :open,
      opened_at: Time.current
    )

    get order_receipt_url(other_order, subdomain: @store.subdomain)

    assert_response :not_found
  end
end
