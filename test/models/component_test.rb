require "test_helper"

class ComponentTest < ActiveSupport::TestCase
  test "ingredients scope returns zero price" do
    assert_includes Component.ingredients, components(:espresso_shot)
    assert_not_includes Component.ingredients, components(:extra_chocolate)
  end

  test "extras scope returns positive price" do
    assert_includes Component.extras, components(:extra_chocolate)
    assert_not_includes Component.extras, components(:espresso_shot)
  end

  test "soft delete" do
    comp = components(:espresso_shot)
    comp.soft_delete!
    assert comp.deleted?
    assert_not_includes Component.active, comp
  end

  test "price_in_cents helpers" do
    comp = components(:extra_chocolate)
    assert_equal 10.0, comp.price
    assert_equal "$10.00", comp.formatted_price
  end
end
