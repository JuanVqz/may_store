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
           params: { payment_method_id: payment_methods(:efectivo).id, received: "45.00" }
    end

    order.reload
    assert_equal "closed", order.status
    assert order.fully_paid?
    assert_redirected_to order_url(order, subdomain: @store.subdomain)
  end

  test "create stores received_cents for cash payment" do
    order = orders(:delivered_order)
    order.payments.destroy_all
    order.update_columns(total_cents: 4500)

    post order_payments_url(order, subdomain: @store.subdomain),
         params: { payment_method_id: payment_methods(:efectivo).id, received: "100.00" }

    payment = order.reload.payments.last
    assert_equal 10000, payment.received_cents
    assert_equal 5500, payment.change_cents
  end

  test "create redirects back to bill when received less than amount" do
    order = orders(:delivered_order)
    order.payments.destroy_all
    order.update_columns(total_cents: 4500)

    assert_no_difference "Payment.count" do
      post order_payments_url(order, subdomain: @store.subdomain),
           params: { payment_method_id: payment_methods(:efectivo).id, received: "20.00" }
    end
    assert_redirected_to bill_order_url(order, subdomain: @store.subdomain)
  end

  test "create with blank received for cash payment fails validation" do
    order = orders(:delivered_order)
    order.payments.destroy_all
    order.update_columns(total_cents: 4500)

    assert_no_difference "Payment.count" do
      post order_payments_url(order, subdomain: @store.subdomain),
           params: { payment_method_id: payment_methods(:efectivo).id, received: "" }
    end
    assert_redirected_to bill_order_url(order, subdomain: @store.subdomain)
  end

  test "create with 0 received for cash payment fails validation" do
    order = orders(:delivered_order)
    order.payments.destroy_all
    order.update_columns(total_cents: 4500)

    assert_no_difference "Payment.count" do
      post order_payments_url(order, subdomain: @store.subdomain),
           params: { payment_method_id: payment_methods(:efectivo).id, received: "0" }
    end
    assert_redirected_to bill_order_url(order, subdomain: @store.subdomain)
  end

  test "create auto-fills received_cents for non-cash payment when blank" do
    order = orders(:delivered_order)
    order.payments.destroy_all
    order.update_columns(total_cents: 4500)

    assert_difference "order.payments.count", 1 do
      post order_payments_url(order, subdomain: @store.subdomain),
           params: { payment_method_id: payment_methods(:mercado_pago).id, received: "" }
    end

    payment = order.reload.payments.last
    assert_equal 4500, payment.received_cents
    assert_equal "closed", order.status
  end

  test "create redirects without creating payment when order already fully paid" do
    order = orders(:delivered_order)
    order.update_columns(total_cents: 4500)
    assert order.reload.fully_paid?

    assert_no_difference "Payment.count" do
      post order_payments_url(order, subdomain: @store.subdomain),
           params: { payment_method_id: payment_methods(:efectivo).id }
    end
    assert_redirected_to order_url(order, subdomain: @store.subdomain)
  end
end
