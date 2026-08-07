require "application_system_test_case"

class BillingTest < ApplicationSystemTestCase
  setup do
    sign_in_waiter
    @order = orders(:delivered_order)
    @order.payments.destroy_all
    @order.update!(total_cents: 4500)
  end

  test "the bill itemizes the order and shows the total" do
    visit bill_order_path(@order)

    assert_text I18n.t("bill.title")
    assert_text @order.code
    assert_text @order.spot.name
    assert_text products(:latte).name
    assert_text I18n.t("bill.total")
    assert_text "$45.00"
  end

  test "the bill lists every active payment method" do
    visit bill_order_path(@order)

    assert_text payment_methods(:efectivo).name
    assert_text payment_methods(:mercado_pago).name
    assert_text payment_methods(:transferencia).name
  end

  test "an inactive payment method is not offered" do
    payment_methods(:transferencia).update!(active: false)

    visit bill_order_path(@order)

    assert_text payment_methods(:efectivo).name
    assert_no_text payment_methods(:transferencia).name
  end

  test "cash payment computes the change" do
    visit bill_order_path(@order)

    choose_payment_method payment_methods(:efectivo)
    fill_in "received", with: "100"

    assert_text "$55.00"
  end

  test "paying in cash closes the order" do
    visit bill_order_path(@order)

    choose_payment_method payment_methods(:efectivo)
    fill_in "received", with: "50"
    click_on I18n.t("bill.confirm_payment")

    assert_text I18n.t("order.closed")
    assert_equal "closed", @order.reload.status
    assert_equal 4500, @order.payments.sum(:amount_cents)
  end

  test "cash received below the total is rejected" do
    visit bill_order_path(@order)

    choose_payment_method payment_methods(:efectivo)
    fill_in "received", with: "10"
    click_on I18n.t("bill.confirm_payment")

    # The rejection comes from the Payment model, so it must still be Spanish.
    assert_text I18n.t("activerecord.attributes.payment.received_cents")
    assert_no_text "Received cents"
    assert_not_equal "closed", @order.reload.status
  end

  test "a non cash method pre-fills the received amount with the total" do
    visit bill_order_path(@order)

    choose_payment_method payment_methods(:mercado_pago)

    # The field stays visible by design; it is filled in so the cashier does
    # not have to retype the exact total.
    assert_equal "45.00", find("#received").value
  end

  test "paying by transfer closes the order" do
    visit bill_order_path(@order)

    choose_payment_method payment_methods(:transferencia)
    click_on I18n.t("bill.confirm_payment")

    assert_text I18n.t("order.closed")
    assert_equal "closed", @order.reload.status
  end

  test "a cancelled item is shown as not charged" do
    order = orders(:cooking_order)
    line_items(:cooking_americano).cancel!(by: users(:waiter_juan))

    visit bill_order_path(order)

    assert_text I18n.t("bill.cancelled")
  end

  test "an already paid order redirects away from the bill" do
    Payment.create!(
      order: @order,
      payment_method: payment_methods(:efectivo),
      amount_cents: @order.total_cents,
      received_cents: @order.total_cents,
      paid_at: Time.current
    )

    visit bill_order_path(@order)

    assert_current_path order_path(@order)
  end

  test "a closed order is terminal and cannot be billed again" do
    @order.update!(status: :closed, closed_at: Time.current)

    visit bill_order_path(@order)

    assert_current_path order_path(@order)
    assert_text I18n.t("order.closed_title")
  end

  test "the bill is reachable from the order screen" do
    order = orders(:ready_order)
    LineItem.create!(order: order, product: products(:americano), status: :ready,
                     base_price_cents: 3500, total_price_cents: 3500)

    visit order_path(order)
    click_on I18n.t("order.request_bill")

    assert_current_path bill_order_path(order)
  end

  private
    def choose_payment_method(method)
      find("label", text: method.name, exact_text: true).click
    end
end
