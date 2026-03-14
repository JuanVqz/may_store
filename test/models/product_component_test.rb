require "test_helper"

class ProductComponentTest < ActiveSupport::TestCase
  test "component_type enum" do
    pc = product_components(:americano_espresso)
    assert pc.ingredient?

    pc.component_type = :extra
    assert pc.extra?
  end

  test "ordered scope sorts by position" do
    product = products(:americano)
    pcs = product.product_components.ordered
    positions = pcs.map(&:position).compact
    assert_equal positions.sort, positions
  end
end
