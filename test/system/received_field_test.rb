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
    find("#received").send_keys("7")

    assert_equal "7", find("#received").value
  end

  test "the change is computed from what was actually typed" do
    page.driver.browser.switch_to.active_element.send_keys("200")

    assert_text "$#{"%.2f" % (200 - @order.total_cents / 100.0)}"
  end
end
