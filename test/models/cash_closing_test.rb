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

  test "open_current! runs from the store's first payment when there is no previous corte" do
    store = stores(:mi_cafe)

    closing = CashClosing.open_current!(store: store, user: users(:other_store_waiter))

    assert_equal Time.current.beginning_of_day.to_i, closing.period_start.to_i
    assert closing.open?
  end

  # Cortes chain, so no sale is counted twice or lost between two of them.
  test "open_current! starts where the previous corte was closed" do
    store = stores(:cafe_delicias)
    previous = CashClosing.open_current!(store: store, user: users(:admin_principal))
    previous.close!

    following = CashClosing.open_current!(store: store, user: users(:admin_principal))

    assert_equal previous.reload.period_end.to_i, following.period_start.to_i
  end

  test "open_current! reuses the open corte instead of overlapping it" do
    store = stores(:cafe_delicias)
    first = CashClosing.open_current!(store: store, user: users(:admin_principal))

    assert_no_difference "CashClosing.count" do
      assert_equal first, CashClosing.open_current!(store: store, user: users(:waiter_juan))
    end
  end

  test "a store can cut the drawer as many times as it likes" do
    store = stores(:cafe_delicias)
    # The fixtures leave one corte open, and the first call would reuse it.
    cash_closings(:open_closing).close!

    assert_difference "CashClosing.count", 3 do
      3.times { CashClosing.open_current!(store: store, user: users(:admin_principal)).close! }
    end
  end

  test "open_current! builds one line per active payment method" do
    store = stores(:cafe_delicias)

    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))

    assert_equal store.payment_methods.active.count, closing.cash_closing_lines.count
  end

  test "refresh_expected! moves the end of an open corte and re-reads the payments" do
    store = stores(:cafe_delicias)
    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    line = closing.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo))
    before = line.expected_cents

    pay store, 1_000

    closing.refresh_expected!

    assert_equal before + 1_000, line.reload.expected_cents
  end

  # A sale rung up while the drawer is being counted belongs to this corte, not
  # to the gap before the next one.
  test "close! takes a final reading before freezing the period" do
    store = stores(:cafe_delicias)
    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    line = closing.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo))
    before = line.expected_cents

    pay store, 700
    closing.close!

    assert closing.closed?
    assert_equal before + 700, line.reload.expected_cents
  end

  test "refresh_expected! leaves a closed corte alone" do
    closing = cash_closings(:open_closing)
    closing.close!
    frozen_end = closing.reload.period_end

    closing.refresh_expected!

    assert_equal frozen_end.to_i, closing.reload.period_end.to_i
  end

  # Two cortes in a row must not both count the same payment.
  test "consecutive cortes split the day's payments between them" do
    store = stores(:cafe_delicias)
    first = CashClosing.open_current!(store: store, user: users(:admin_principal))
    pay store, 500
    first.close!
    counted_first = first.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo)).expected_cents

    second = CashClosing.open_current!(store: store, user: users(:admin_principal))
    pay store, 300
    second.close!
    counted_second = second.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo)).expected_cents

    assert_equal 300, counted_second
    assert_equal counted_first + 300, counted_first + counted_second - 0
  end

  test "period_label reads as a date and a time range" do
    closing = cash_closings(:open_closing)

    assert_match(/\d{2}:\d{2} - \d{2}:\d{2}/, closing.period_label)
  end

  private

  def pay(store, cents, method: payment_methods(:efectivo))
    order = store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                 opened_at: Time.current, total_cents: cents)
    order.payments.create!(payment_method: method, amount_cents: cents,
                           received_cents: cents, paid_at: Time.current)
  end
end
