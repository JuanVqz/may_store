require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "create pays remaining total and closes order" do
    order = orders(:delivered_order)
    order.payments.destroy_all
    order.update_columns(total_cents: 4500)

    assert_difference "order.payments.count", 1 do
      post order_payments_url(order, subdomain: @store.subdomain),
           params: { payment_method_id: payment_methods(:efectivo).id }
    end

    order.reload
    assert_equal "closed", order.status
    assert order.fully_paid?
    assert_redirected_to order_url(order, subdomain: @store.subdomain)
  end
end
