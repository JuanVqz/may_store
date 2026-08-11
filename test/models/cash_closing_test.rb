require "test_helper"

class CashClosingTest < ActiveSupport::TestCase
  test "status enum" do
    closing = cash_closings(:open_closing)
    assert closing.open?
    closing.update!(status: :closed, closed_at: Time.current)
    assert closing.closed?
  end

  test "total helpers sum from cash_closing_lines" do
    closing = cash_closings(:open_closing)
    expected_sum = closing.cash_closing_lines.sum(:expected_cents)
    assert_equal expected_sum, closing.total_expected_cents

    actual_sum = closing.cash_closing_lines.sum(:actual_cents)
    assert_equal actual_sum, closing.total_actual_cents

    diff_sum = closing.cash_closing_lines.sum(:difference_cents)
    assert_equal diff_sum, closing.total_difference_cents
  end

  test "open_for_today! covers the whole calendar day" do
    closing = CashClosing.open_for_today!(store: stores(:cafe_delicias), user: users(:admin_principal))

    assert_equal Time.current.beginning_of_day.to_i, closing.period_start.to_i
    assert_equal Time.current.end_of_day.to_i, closing.period_end.to_i
    assert closing.open?
  end

  test "open_for_today! reuses the day's open corte instead of starting a rival count" do
    store = stores(:cafe_delicias)
    first = CashClosing.open_for_today!(store: store, user: users(:admin_principal))

    assert_no_difference "CashClosing.count" do
      assert_equal first, CashClosing.open_for_today!(store: store, user: users(:waiter_juan))
    end
  end

  test "open_for_today! opens a fresh corte once the day's one is closed" do
    store = stores(:cafe_delicias)
    CashClosing.open_for_today!(store: store, user: users(:admin_principal)).close!

    assert_difference "CashClosing.count", 1 do
      CashClosing.open_for_today!(store: store, user: users(:admin_principal))
    end
  end

  test "open_for_today! builds one line per active payment method and refreshes expected" do
    store = stores(:cafe_delicias)
    closing = CashClosing.open_for_today!(store: store, user: users(:admin_principal))

    assert_equal store.payment_methods.active.count, closing.cash_closing_lines.count

    order = store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                 opened_at: Time.current, total_cents: 1_000)
    order.payments.create!(payment_method: payment_methods(:efectivo), amount_cents: 1_000,
                           received_cents: 1_000, paid_at: Time.current)

    CashClosing.open_for_today!(store: store, user: users(:admin_principal))
    line = closing.reload.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo))

    assert_equal 1_000, line.expected_cents
  end

  test "period_label reads as a date and a time range" do
    closing = cash_closings(:open_closing)

    assert_match(/\d{2}:\d{2} - \d{2}:\d{2}/, closing.period_label)
  end
end
