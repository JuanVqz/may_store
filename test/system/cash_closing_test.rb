require "application_system_test_case"

class CashClosingTest < ApplicationSystemTestCase
  setup do
    sign_in_admin
  end

  test "opening a corte lists every active payment method with its expected total" do
    visit_store stores(:cafe_delicias), admin_cash_closings_path
    click_on I18n.t("admin.new_cash_closing")

    assert_text I18n.t("cash_closing.title")
    stores(:cafe_delicias).payment_methods.active.each { |method| assert_text method.name }
  end

  test "the difference updates as the admin types the counted amount" do
    closing = open_corte
    line = closing.cash_closing_lines.order(:id).first

    visit_store stores(:cafe_delicias), admin_cash_closing_path(closing)

    row = find("tr", text: line.payment_method.name)
    row.find("input[type=number]").set("10.00")

    # Expected is 0.00 with no payments in the period, so counting 10 is a surplus.
    assert_text "+$10.00"
  end

  test "closing the corte freezes the count" do
    closing = open_corte

    visit_store stores(:cafe_delicias), admin_cash_closing_path(closing)
    accept_confirm { click_on I18n.t("cash_closing.close") }

    assert_text I18n.t("cash_closing_statuses.closed")
    assert_no_selector "input[type=number]:not([disabled])"
    assert closing.reload.closed?
  end

  private

  def open_corte
    CashClosing.open_current!(store: stores(:cafe_delicias), user: users(:admin_principal))
  end
end
