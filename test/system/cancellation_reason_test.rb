require "application_system_test_case"

class CancellationReasonTest < ApplicationSystemTestCase
  setup do
    @order = orders(:cooking_order)
    @order.payments.destroy_all
    @item = @order.line_items.first
    @item.cancel!(by: users(:waiter_juan))
    sign_in_waiter
  end

  # Cancelling records a default so nobody has to stop and think; that only pays
  # off if the guess can be corrected, and correcting it is one choice with no
  # save button.
  test "choosing a reason saves it without a save button" do
    visit_store stores(:cafe_delicias), order_bill_path(@order)

    select I18n.t("cancellation_reasons.kitchen_error"), from: dom_id(@item, :cancellation_reason)

    assert_selector "select", text: I18n.t("cancellation_reasons.kitchen_error")
    assert_equal "kitchen_error", @item.reload.cancellation_reason
  end

  test "the default reason is the one shown before anyone corrects it" do
    visit_store stores(:cafe_delicias), order_bill_path(@order)

    assert_equal LineItem::DEFAULT_CANCELLATION_REASON,
                 find("##{dom_id(@item, :cancellation_reason)}").value
  end
end
