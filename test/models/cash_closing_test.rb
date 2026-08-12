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

  # The hole that claiming exists to close: a payment written with a paid_at
  # inside an already-closed period is too late for that corte and too early for
  # a period-based next one, so a time window would count it in neither.
  test "a backdated payment is counted by the next corte" do
    store = stores(:cafe_delicias)
    CashClosing.open_current!(store: store, user: users(:admin_principal)).close!

    pay store, 900, paid_at: 3.days.ago

    following = CashClosing.open_current!(store: store, user: users(:admin_principal))
    line = following.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo))

    assert_equal 900, line.expected_cents
  end

  # cancel! leaves payments alone, so money taken for an order that was later
  # cancelled is still in the drawer and still has to be counted.
  test "a cancelled order's payments are still counted" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    order = pay(store, 400).order
    order.cancel!

    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    line = closing.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo))

    assert_equal 400, line.expected_cents
  end

  test "closing claims the payments it counted so no later corte can count them again" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    payment = pay(store, 250)

    first = CashClosing.open_current!(store: store, user: users(:admin_principal))
    first.close!

    assert_equal first, payment.reload.cash_closing

    second = CashClosing.open_current!(store: store, user: users(:admin_principal))
    assert_equal 0, second.total_expected_cents
  end

  test "a closed corte's totals do not move when new money arrives" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    pay store, 100
    closing.close!
    counted = closing.total_expected_cents

    pay store, 5_000
    closing.calculate_expected!

    assert_equal counted, closing.reload.total_expected_cents
  end

  # Two cortes in a row must not both count the same payment.
  test "consecutive cortes split the day's payments between them" do
    store = stores(:cafe_delicias)
    # Whatever the fixtures left uncounted lands in the first corte, so the
    # assertion below is about the money added between the two closes.
    already_uncounted = Payment.joins(:order).where(orders: { store_id: store.id })
                               .uncounted.where(payment_method: payment_methods(:efectivo))
                               .sum(:amount_cents)
    first = CashClosing.open_current!(store: store, user: users(:admin_principal))
    pay store, 500
    first.close!
    counted_first = first.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo)).expected_cents

    second = CashClosing.open_current!(store: store, user: users(:admin_principal))
    pay store, 300
    second.close!
    counted_second = second.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo)).expected_cents

    assert_equal 500, counted_first - already_uncounted
    assert_equal 300, counted_second
  end

  # Money taken on a method that is deactivated afterwards is still money in the
  # drawer, and the corte claims it either way. Without a line for it, it was
  # claimed while appearing in no total, so no corte ever accounted for it.
  test "a payment on a since-deactivated method is still counted" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    method = payment_methods(:mercado_pago)
    pay store, 50_000, method: method
    method.update!(active: false)

    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    line = closing.cash_closing_lines.find_by(payment_method: method)

    assert_equal 50_000, line.expected_cents
    assert_equal 50_000, closing.total_expected_cents
  end

  # A line left over from a method deactivated mid-corte still counts towards the
  # total, so it has to be recomputed rather than skipped.
  test "an existing line for a deactivated method is recomputed, not left stale" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    method = payment_methods(:mercado_pago)
    payment = pay(store, 700, method: method)
    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    assert_equal 700, closing.cash_closing_lines.find_by(payment_method: method).expected_cents

    method.update!(active: false)
    payment.destroy!
    closing.refresh_expected!

    assert_equal 0, closing.cash_closing_lines.find_by(payment_method: method).expected_cents
  end

  # The screen reads the lines it preloaded, so a recalculation that only touched
  # fresh instances left the rows showing the old expected amounts while the SQL
  # total showed the new ones.
  test "refresh_expected! is visible through an already-loaded association" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    closing.cash_closing_lines.load
    pay store, 2_500

    closing.refresh_expected!

    assert_equal 2_500, closing.cash_closing_lines.sum(&:expected_cents)
    assert_equal closing.total_expected_cents, closing.cash_closing_lines.sum(&:expected_cents)
  end

  # The totals a closed corte freezes have to describe exactly the payments it
  # claimed, which is why closing claims first and reads afterwards.
  test "closing freezes totals that match the payments it claimed" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    closing = CashClosing.open_current!(store: store, user: users(:admin_principal))
    pay store, 1_200
    pay store, 800, method: payment_methods(:mercado_pago)

    closing.close!

    claimed = Payment.where(cash_closing: closing).sum(:amount_cents)
    assert_equal 2_000, claimed
    assert_equal claimed, closing.total_expected_cents
  end

  # The invariant the whole chain rests on, held by the database rather than by
  # the read-then-create in open_current!.
  test "the database refuses a second open corte for the same store" do
    store = stores(:cafe_delicias)

    assert_raises ActiveRecord::RecordNotUnique do
      CashClosing.connection.execute(
        CashClosing.sanitize_sql([
          "INSERT INTO cash_closings (store_id, user_id, status, period_start, period_end, created_at, updated_at) " \
          "VALUES (?, ?, 'open', ?, ?, ?, ?)",
          store.id, users(:admin_principal).id, Time.current, Time.current, Time.current, Time.current
        ])
      )
    end
  end

  # The index is partial, so it constrains only the open ones: a store accumulates
  # closed cortes forever and still gets to open the next one.
  test "a store can hold many closed cortes alongside one open" do
    store = stores(:cafe_delicias)
    cash_closings(:open_closing).close!
    CashClosing.open_current!(store: store, user: users(:admin_principal)).close!
    CashClosing.open_current!(store: store, user: users(:admin_principal))

    assert_equal 1, CashClosing.where(store: store, status: :open).count
    assert_operator CashClosing.where(store: store, status: :closed).count, :>=, 2
  end

  test "period_label reads as a date and a time range" do
    closing = cash_closings(:open_closing)

    assert_match(/\d{2}:\d{2} - \d{2}:\d{2}/, closing.period_label)
  end

  private

  def pay(store, cents, method: payment_methods(:efectivo), paid_at: Time.current)
    order = store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                 opened_at: Time.current, total_cents: cents)
    order.payments.create!(payment_method: method, amount_cents: cents,
                           received_cents: cents, paid_at: paid_at)
  end
end
