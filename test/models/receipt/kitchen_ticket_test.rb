require "test_helper"

class Receipt::KitchenTicketTest < ActiveSupport::TestCase
  setup do
    @order = orders(:cooking_order)
  end

  test "prints the spot, code and server" do
    text = printable(@order)

    assert_includes text, @order.spot.name
    assert_includes text, @order.code
    assert_includes text, @order.user.name
  end

  test "prints product names in upper case for reading across the line" do
    assert_includes printable(@order), @order.line_items.first.product.name.upcase
  end

  test "groups items under their prep station" do
    @order.add_item!(product: products(:crepa_nutella))

    text = printable(@order.reload)

    assert_includes text, "BARRA"
    assert_includes text, "COCINA"
    # Station order follows Category.stations, same as the kitchen screen, so a
    # cook reads the paper ticket in the order they see on the tablet.
    assert_operator text.index("COCINA"), :<, text.index("BARRA")
  end

  test "a station ticket prints only that station's items and drops the group headings" do
    @order.add_item!(product: products(:crepa_nutella))

    text = printable(@order.reload, station: "kitchen")

    assert_includes text, "CREPA DE NUTELLA"
    assert_not_includes text, "CAPPUCCINO CARAMEL"
    assert_includes text, "Cocina"
  end

  test "an unknown station is treated as no filter by the caller, not here" do
    text = printable(@order, station: "nowhere")

    assert_not_includes text, "CAPPUCCINO CARAMEL"
  end

  test "leaves cancelled items off the ticket" do
    item = @order.line_items.first
    item.update!(status: :cancelled)

    assert_not_includes printable(@order.reload), item.product.name.upcase
  end

  # This ticket is printed on demand, so a cook picking up a reprint mid-service
  # must be able to tell what is still to make.
  test "marks items that are already done and leaves pending ones clean" do
    pending, done = @order.line_items.order(:created_at).to_a
    done.update!(status: :ready)

    text = printable(@order.reload)

    assert_match(/#{done.product.name.upcase}\n\s*>> LISTO/, text)
    assert_no_match(/#{pending.product.name.upcase}\n\s*>>/, text)
  end

  test "marks an item a waiter already carried out" do
    @order.line_items.first.update!(status: :delivered)

    assert_includes printable(@order.reload), ">> ENTREGADO"
  end

  # The bill prints only what the customer changed; the cook needs the recipe,
  # so the full ingredient list stays on the ticket.
  test "keeps every ingredient, including the ones left standard" do
    item = orders(:cooking_order).line_items.first
    component = components(:steamed_milk)
    item.line_item_components.create!(component: component, component_type: :ingredient, portion: 1.0, unit_price_cents: 0)

    text = printable(orders(:cooking_order).reload)

    assert_includes text, "#{component.name}: #{I18n.t("portions.full")}"
  end

  test "prints special notes in bold so the cook cannot miss them" do
    @order.line_items.first.update!(special_notes: "sin azucar")

    bytes = Receipt::KitchenTicket.new(@order.reload).to_escpos

    assert_includes bytes, "\eE\x01".b
    assert_includes printable(@order), "NOTAS: sin azucar"
  end

  private

  # Rendered through the preview so assertions see the paper's text without the
  # control sequences interleaved between words.
  def printable(order, station: nil)
    EscPos::Preview.new(Receipt::KitchenTicket.new(order, station: station).to_escpos).to_text
  end
end
