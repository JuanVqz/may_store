require "test_helper"

class Receipt::BillTest < ActiveSupport::TestCase
  setup do
    @order = orders(:cooking_order)
  end

  test "prints the store, spot, code and server" do
    text = printable(@order)

    assert_includes text, @order.store.name
    assert_includes text, @order.spot.name
    assert_includes text, @order.code
    assert_includes text, @order.user.name
  end

  test "prints every item with its price" do
    text = printable(@order)

    @order.line_items.each do |item|
      assert_includes text, item.product.name
      assert_includes text, item.formatted_total_price
    end
  end

  test "prints the order total" do
    assert_includes printable(@order), @order.formatted_total
  end

  test "marks a cancelled item instead of pricing it" do
    item = @order.line_items.first
    item.update!(status: :cancelled)

    text = printable(@order.reload)

    assert_match(/#{Regexp.escape(item.product.name)}.*CANCELADO/, text)
  end

  test "prints ingredient portions and extras under their item" do
    item = @order.line_items.first
    component = components(:steamed_milk)
    item.line_item_components.create!(component: component, component_type: :ingredient, portion: 0.5, unit_price_cents: 0)
    item.line_item_components.create!(component: component, component_type: :extra, portion: 1.0, unit_price_cents: 500)

    text = printable(@order.reload)

    assert_includes text, "#{component.name}: 1/2"
    assert_includes text, "+ #{component.name} x1"
  end

  # A plain product used to print its whole recipe as "Normal", six lines of
  # paper telling the customer nothing was changed.
  test "leaves out ingredients kept at their standard portion" do
    item = @order.line_items.first
    component = components(:steamed_milk)
    item.line_item_components.create!(component: component, component_type: :ingredient, portion: 1.0, unit_price_cents: 0)

    text = printable(@order.reload)

    assert_not_includes text, "#{component.name}: #{I18n.t("portions.full")}"
  end

  test "a cancelled item prints as one line, with no description of what nobody got" do
    item = @order.line_items.first
    component = components(:steamed_milk)
    item.line_item_components.create!(component: component, component_type: :extra, portion: 1.0, unit_price_cents: 500)
    item.update!(special_notes: "sin azucar", status: :cancelled)

    text = printable(@order.reload)

    assert_match(/#{Regexp.escape(item.product.name)}.*CANCELADO/, text)
    assert_not_includes text, "+ #{component.name}"
    assert_not_includes text, "sin azucar"
  end

  test "prints special notes" do
    @order.line_items.first.update!(special_notes: "sin azucar")

    assert_includes printable(@order.reload), "sin azucar"
  end

  test "a cash payment prints what was handed over and the change" do
    @order.payments.create!(
      payment_method: payment_methods(:efectivo),
      amount_cents: @order.total_cents,
      received_cents: @order.total_cents + 5_500
    )

    text = printable(@order.reload)

    assert_includes text, "Pagado con"
    assert_includes text, "Recibido"
    assert_includes text, "Cambio"
    assert_includes text, "$55.00"
  end

  # On a transfer the received amount is the total by definition, so the pair
  # would be noise on the paper.
  test "a non-cash payment prints the method without received or change" do
    @order.payments.create!(
      payment_method: payment_methods(:transferencia),
      amount_cents: @order.total_cents,
      received_cents: @order.total_cents
    )

    text = printable(@order.reload)

    assert_includes text, "Transferencia"
    assert_not_includes text, "Recibido"
    assert_not_includes text, "Cambio"
  end

  test "ends with a cut so the next bill starts on fresh paper" do
    assert Receipt::Bill.new(@order).to_escpos.end_with?("\x1dVA\x00".b)
  end

  private

  # Decodes the stream back to UTF-8 so assertions read like the paper does.
  def printable(order)
    Receipt::Bill.new(order).to_escpos.dup.force_encoding("CP437").encode("UTF-8")
  end
end
