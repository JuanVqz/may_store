require "test_helper"

class Admin::CashClosingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "ADM-001", password: "password123" }
  end

  test "index lists cortes with their difference" do
    get admin_cash_closings_url(subdomain: @store.subdomain)

    assert_response :success
    assert_match cash_closings(:open_closing).user.name, response.body
  end

  test "create opens a corte running from the last close up to now" do
    previous = cash_closings(:open_closing)
    previous.close!

    assert_difference "CashClosing.count", 1 do
      post admin_cash_closings_url(subdomain: @store.subdomain)
    end

    closing = @store.cash_closings.find_by(status: :open)
    assert_redirected_to admin_cash_closing_url(closing, subdomain: @store.subdomain)
    assert_equal previous.reload.period_end.to_i, closing.period_start.to_i
    assert_in_delta Time.current, closing.period_end, 5.seconds
    assert_equal @store.payment_methods.active.count, closing.cash_closing_lines.count
  end

  # Two open cortes would overlap and count the same money twice.
  test "create reuses the open corte instead of opening a second one" do
    open_corte = cash_closings(:open_closing)

    assert_no_difference "CashClosing.count" do
      post admin_cash_closings_url(subdomain: @store.subdomain)
    end

    assert_redirected_to admin_cash_closing_url(open_corte, subdomain: @store.subdomain)
  end

  test "a store can cut the drawer as many times as it likes" do
    cash_closings(:open_closing).close!

    assert_difference "CashClosing.count", 2 do
      2.times do
        post admin_cash_closings_url(subdomain: @store.subdomain)
        @store.cash_closings.find_by(status: :open).close!
      end
    end
  end

  test "update saves the counted amounts in cents" do
    closing = cash_closings(:open_closing)
    line = closing.cash_closing_lines.first

    patch admin_cash_closing_url(closing, subdomain: @store.subdomain), params: {
      cash_closing: {
        notes: "faltaron cincuenta",
        cash_closing_lines_attributes: [{ id: line.id, actual: "95.50" }]
      }
    }

    assert_redirected_to admin_cash_closing_url(closing, subdomain: @store.subdomain)
    assert_equal 9_550, line.reload.actual_cents
    assert_equal 9_550 - line.expected_cents, line.difference_cents
    assert_equal "faltaron cincuenta", closing.reload.notes
  end

  test "update with close closes the corte" do
    closing = cash_closings(:open_closing)

    patch admin_cash_closing_url(closing, subdomain: @store.subdomain), params: {
      close: "1", cash_closing: { notes: "" }
    }

    assert closing.reload.closed?
    assert_not_nil closing.closed_at
  end

  test "a closed corte cannot be edited again" do
    closing = cash_closings(:open_closing)
    closing.close!
    line = closing.cash_closing_lines.first

    patch admin_cash_closing_url(closing, subdomain: @store.subdomain), params: {
      cash_closing: { cash_closing_lines_attributes: [{ id: line.id, actual: "1.00" }] }
    }

    assert_redirected_to admin_cash_closing_url(closing, subdomain: @store.subdomain)
    assert_not_equal 100, line.reload.actual_cents
  end

  test "requires authentication" do
    delete logout_url(subdomain: @store.subdomain)

    get admin_cash_closings_url(subdomain: @store.subdomain)

    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  # Role is the default screen, not a permission: a waiter reaching this is fine.
  test "any role can reach it" do
    delete logout_url(subdomain: @store.subdomain)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }

    get admin_cash_closings_url(subdomain: @store.subdomain)

    assert_response :success
  end

  test "cannot reach another store's corte" do
    other_store = stores(:mi_cafe)
    other = other_store.cash_closings.create!(
      user: users(:other_store_waiter), status: :open,
      period_start: Time.current.beginning_of_day, period_end: Time.current.end_of_day
    )

    get admin_cash_closing_url(other, subdomain: @store.subdomain)

    assert_response :not_found
  end

  test "receipt streams the corte as ESC/POS bytes" do
    closing = cash_closings(:open_closing)

    get admin_cash_closing_receipt_url(closing, subdomain: @store.subdomain)

    assert_response :success
    assert_equal "application/vnd.escpos", response.media_type
    assert_includes response.body, I18n.t("cash_closing.title")
  end

  # The paper is what gets signed and filed, so it is the last place that should
  # carry a number left over from an earlier screen.
  test "receipt refreshes an open corte before printing it" do
    closing = CashClosing.open_current!(store: @store, user: users(:admin_principal))
    line = closing.cash_closing_lines.first
    before = line.expected_cents

    order = @store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                  opened_at: Time.current, total_cents: 3_100)
    order.payments.create!(payment_method: line.payment_method, amount_cents: 3_100,
                           received_cents: 3_100, paid_at: Time.current)

    get admin_cash_closing_receipt_url(closing, subdomain: @store.subdomain)

    assert_response :success
    assert_equal before + 3_100, line.reload.expected_cents
  end

  test "receipt leaves a closed corte frozen" do
    closing = cash_closings(:open_closing)
    closing.close!
    line = closing.cash_closing_lines.first

    assert_no_changes -> { line.reload.expected_cents } do
      get admin_cash_closing_receipt_url(closing, subdomain: @store.subdomain)
    end
  end

  # Expected is derived from the day's payments, so an open corte left on screen
  # while sales come in must not keep showing the number it was opened with.
  test "show refreshes the expected total of an open corte" do
    closing = CashClosing.open_current!(store: @store, user: users(:admin_principal))
    line = closing.cash_closing_lines.find_by(payment_method: payment_methods(:efectivo))
    before = line.expected_cents

    order = @store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                  opened_at: Time.current, total_cents: 2_500)
    order.payments.create!(payment_method: payment_methods(:efectivo), amount_cents: 2_500,
                           received_cents: 2_500, paid_at: Time.current)

    get admin_cash_closing_url(closing, subdomain: @store.subdomain)

    assert_response :success
    assert_equal before + 2_500, line.reload.expected_cents
  end

  # A closed corte is a record of a moment and must not move afterwards.
  test "show leaves a closed corte's expected total alone" do
    closing = cash_closings(:open_closing)
    line = closing.cash_closing_lines.first
    closing.close!

    order = @store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                  opened_at: closing.period_start, total_cents: 2_500)
    order.payments.create!(payment_method: line.payment_method, amount_cents: 2_500,
                           received_cents: 2_500, paid_at: closing.period_start + 1.hour)

    assert_no_changes -> { line.reload.expected_cents } do
      get admin_cash_closing_url(closing, subdomain: @store.subdomain)
    end
  end

  # The screen reads the lines it preloaded, and the live difference the Stimulus
  # controller shows comes off data-expected. Rendering a stale number there put a
  # phantom shortfall on screen for money that was never missing, which is exactly
  # what refreshing on GET exists to prevent.
  test "show renders the refreshed expected amount, not the preloaded one" do
    closing = CashClosing.open_current!(store: @store, user: users(:admin_principal))
    method = closing.cash_closing_lines.first.payment_method
    get admin_cash_closing_url(closing, subdomain: @store.subdomain)

    order = @store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                  opened_at: Time.current, total_cents: 2_500)
    order.payments.create!(payment_method: method, amount_cents: 2_500,
                           received_cents: 2_500, paid_at: Time.current)

    get admin_cash_closing_url(closing, subdomain: @store.subdomain)

    rendered = response.body.scan(/data-expected="(\d+)"/).flatten.sum(&:to_i)
    assert_equal closing.reload.total_expected_cents, rendered
  end

  # Minus the whole drawer is not a shortfall when nobody has counted it yet.
  # A corte that reports a difference and nothing else gives nobody a way to find
  # it. The payments behind the expected total are what the cashier reads to spot
  # the sale rung on the wrong method, or the one nobody rang.
  test "show lists the payments behind an open corte's expected total" do
    closing = CashClosing.open_current!(store: @store, user: users(:admin_principal))
    payment = payments(:pago_efectivo)

    get admin_cash_closing_url(closing, subdomain: @store.subdomain)

    assert_response :success
    assert_match payment.order.code, response.body
    assert_match payment.formatted_amount, response.body
    assert_match I18n.t("cash_closing.payments_hint_open"), response.body
  end

  # A closed corte lists exactly what it claimed, and money that arrived after it
  # closed belongs to the next one: showing it here would double-count it to
  # anyone reading the screen.
  test "show lists only the payments a closed corte claimed" do
    closing = cash_closings(:open_closing)
    closing.close!
    claimed = closing.payments.first

    later_order = @store.orders.create!(spot: spots(:mesa_2), user: users(:waiter_juan), status: :closed,
                                        opened_at: Time.current, total_cents: 3_300)
    later = later_order.payments.create!(payment_method: payment_methods(:efectivo), amount_cents: 3_300,
                                         received_cents: 3_300, paid_at: Time.current)

    get admin_cash_closing_url(closing, subdomain: @store.subdomain)

    assert_response :success
    assert_match claimed.order.code, response.body
    assert_no_match(/#{Regexp.escape(later.order.code)}/, response.body)
    assert_match I18n.t("cash_closing.payments_hint_closed"), response.body
  end

  test "index labels an uncounted open corte instead of showing it as short" do
    closing = CashClosing.open_current!(store: @store, user: users(:admin_principal))
    closing.cash_closing_lines.update_all(actual_cents: 0)

    get admin_cash_closings_url(subdomain: @store.subdomain)

    assert_response :success
    assert_includes response.body, I18n.t("cash_closing.not_counted")
  end

  test "index shows the difference once a count has been entered" do
    closing = CashClosing.open_current!(store: @store, user: users(:admin_principal))
    closing.cash_closing_lines.first.update!(actual_cents: 100)

    get admin_cash_closings_url(subdomain: @store.subdomain)

    assert_response :success
    assert_not_includes response.body, I18n.t("cash_closing.not_counted")
  end

  # The catalogue is set up once; the corte is opened every day.
  test "the admin root is the corte de caja" do
    get admin_root_url(subdomain: @store.subdomain)

    assert_response :success
    assert_match I18n.t("admin.cash_closings.title"), response.body
  end
end
