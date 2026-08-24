require "test_helper"

class LineItem::CustomizableTest < ActiveSupport::TestCase
  setup do
    @order = orders(:open_order)
    @product = products(:cappuccino)
    @chocolate = components(:extra_chocolate)
  end

  test "every ingredient of the product lands on the item at a full portion" do
    item = build_item.customize!

    assert_equal @product.product_components.ingredient.count,
                 item.line_item_components.ingredient.count
    assert_equal [1.0], item.line_item_components.ingredient.pluck(:portion).uniq
  end

  test "a portion asked for on the form wins over the default" do
    item = build_item.customize!(portions: { components(:steamed_milk).id.to_s => "0.5" })

    milk = item.line_item_components.find_by(component: components(:steamed_milk))
    assert_equal 0.5, milk.portion
    assert_equal 1.0, item.line_item_components.find_by(component: components(:espresso_shot)).portion
  end

  # "Double chocolate" is two rows, not one row with a quantity: there is no
  # unique index on the join for exactly this reason, and the total has to
  # charge for both.
  test "an extra asked for twice is charged twice" do
    item = build_item.customize!(extras: { @chocolate.id.to_s => "2" })

    assert_equal 2, item.line_item_components.extra.where(component: @chocolate).count
    assert_equal @product.base_price_cents + (2 * @chocolate.price_cents), item.total_price_cents
  end

  # A stale form, or a hand-made post, can name a component the product does not
  # offer. Charging for it would put a price on the bill nobody can explain.
  test "an extra the product does not offer is ignored" do
    item = build_item.customize!(extras: { components(:extra_strawberries).id.to_s => "1" })

    assert_equal 0, item.line_item_components.extra.count
    assert_equal @product.base_price_cents, item.total_price_cents
  end

  test "no extras leaves the item at the product's own price" do
    item = build_item.customize!

    assert_equal @product.base_price_cents, item.total_price_cents
  end

  private

  def build_item
    @order.line_items.create!(product: @product, status: :ordering,
                              base_price_cents: @product.base_price_cents)
  end
end
