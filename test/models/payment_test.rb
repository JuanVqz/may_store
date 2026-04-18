require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "validates amount_cents is positive" do
    payment = Payment.new(
      order: orders(:delivered_order),
      payment_method: payment_methods(:efectivo),
      amount_cents: 0,
      received_cents: 0
    )
    assert_not payment.valid?
  end

  test "price helpers from PriceCents" do
    payment = payments(:pago_efectivo)
    assert payment.formatted_amount.start_with?("$")
  end

  test "received_cents must be present" do
    payment = Payment.new(
      order: orders(:delivered_order),
      payment_method: payment_methods(:efectivo),
      amount_cents: 4500,
      received_cents: nil
    )
    assert_not payment.valid?
  end

  test "received_cents must be >= amount_cents" do
    payment = Payment.new(
      order: orders(:delivered_order),
      payment_method: payment_methods(:efectivo),
      amount_cents: 4500,
      received_cents: 4000
    )
    assert_not payment.valid?
  end

  test "change_cents returns difference when received > amount" do
    payment = Payment.new(amount_cents: 4500, received_cents: 10000)
    assert_equal 5500, payment.change_cents
    assert_equal "$55.00", payment.formatted_change
  end

  test "change_cents is zero when received equals amount" do
    payment = Payment.new(amount_cents: 4500, received_cents: 4500)
    assert_equal 0, payment.change_cents
  end
end
