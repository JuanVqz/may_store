require "test_helper"

class CashClosingLineTest < ActiveSupport::TestCase
  test "calculates difference before save" do
    # Closed, because only one corte per store may be open and the fixtures
    # already leave one open for this store.
    closing = CashClosing.create!(
      store: stores(:cafe_delicias),
      user: users(:admin_principal),
      status: :closed,
      period_start: 1.day.ago,
      period_end: Time.current
    )

    line = CashClosingLine.create!(
      cash_closing: closing,
      payment_method: payment_methods(:efectivo),
      expected_cents: 10000,
      actual_cents: 9500
    )

    assert_equal(-500, line.difference_cents)
  end
end
