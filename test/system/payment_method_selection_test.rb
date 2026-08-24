require "application_system_test_case"

class PaymentMethodSelectionTest < ApplicationSystemTestCase
  setup do
    @order = orders(:delivered_order)
    @order.payments.destroy_all
    sign_in_waiter
    visit_store stores(:cafe_delicias), order_bill_path(@order)
  end

  # Styled with group-has rather than peer-checked, because ReActionView's
  # development debug_mode wraps ERB output in a <span display:contents> and
  # breaks any sibling selector. See the comment in orders/bill.html.erb.
  test "the first payment method is selected on load and shows it" do
    assert_equal "Efectivo", first("label span").text.strip
    assert selected?("Efectivo"), "expected Efectivo to be highlighted on load"
  end

  test "picking another method moves the highlight" do
    find("label", text: "Transferencia").click

    assert selected?("Transferencia"), "expected Transferencia to be highlighted"
    assert_not selected?("Efectivo"), "expected Efectivo to lose its highlight"
  end

  # The regression this styling exists for. ReActionView's development debug_mode
  # wraps every ERB output in <span style="display:contents">, which moves the
  # radio out of sibling position. peer-checked broke silently under that; the
  # highlight was invisible in development and fine in test and production. Test
  # runs with debug_mode off, so the wrapper is recreated here on purpose.
  test "the highlight survives a wrapper around the radio, as in development" do
    page.execute_script(<<~JS)
      document.querySelectorAll("label input[type=radio]").forEach((input) => {
        const wrapper = document.createElement("span")
        wrapper.style.display = "contents"
        input.parentNode.insertBefore(wrapper, input)
        wrapper.appendChild(input)
      })
    JS

    # Clicked rather than trusting the pre-checked state: moving a radio between
    # parents can clear its checkedness, which would make this assert the DOM
    # move rather than the styling.
    find("label", text: "Mercado Pago").click

    assert selected?("Mercado Pago"), "expected the highlight to work with a wrapper present"
    assert_not selected?("Efectivo")
  end

  private

  # Transparent means unhighlighted; the selected one is painted with --primary.
  def selected?(name)
    span = find("label span", text: name)
    span.evaluate_script("getComputedStyle(this).backgroundColor") != "rgba(0, 0, 0, 0)"
  end
end
