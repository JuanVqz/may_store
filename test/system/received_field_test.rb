require "application_system_test_case"

class ReceivedFieldTest < ApplicationSystemTestCase
  setup do
    @order = orders(:delivered_order)
    @order.payments.destroy_all
    sign_in_waiter
    visit_store stores(:cafe_delicias), bill_order_path(@order)
  end

  # The field is autofocused and pre-filled with 0.00, so typing 5 to mean five
  # pesos used to land beside the zeros and read as 50.00.
  test "typing straight away replaces the pre-filled amount" do
    page.driver.browser.switch_to.active_element.send_keys("5")

    assert_equal "5", find("#received").value
  end

  test "coming back to the field by click replaces it too" do
    # Leave the field first, then click back into it with a real mouse click.
    # `find("#received").send_keys` goes through Selenium's Element Send Keys,
    # which focuses with no mouse events at all, so it would exercise the same
    # path as the test above and leave the click path uncovered.
    find("[data-payment-form-target='change']").click
    find("#received").click
    page.driver.browser.switch_to.active_element.send_keys("7")

    assert_equal "7", find("#received").value
  end

  test "the change is computed from what was actually typed" do
    # Derived from the total so the typed amount always covers it. Below the
    # total, recalc blanks the change and the assertion would chase a negative.
    received = "%.2f" % ((@order.total_cents + 10_000) / 100.0)

    page.driver.browser.switch_to.active_element.send_keys(received)

    assert_text "$100.00"
  end
end
