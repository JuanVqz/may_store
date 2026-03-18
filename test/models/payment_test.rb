require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "validates amount_cents is positive" do
    payment = Payment.new(
      order: orders(:delivered_order),
      payment_method: payment_methods(:efectivo),
      amount_cents: 0
    )
    assert_not payment.valid?
  end

  test "price helpers from PriceCents" do
    payment = payments(:pago_efectivo)
    assert payment.formatted_amount.start_with?("$")
  end
end
