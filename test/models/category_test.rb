require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "ordered scope sorts by position" do
    categories = Category.where(store: stores(:cafe_delicias)).ordered
    positions = categories.map(&:position).compact
    assert_equal positions.sort, positions
  end

  test "soft delete sets deleted_at" do
    category = categories(:bebidas_calientes)
    category.soft_delete!
    assert category.deleted?
    assert_not_nil category.deleted_at
  end

  test "active scope excludes soft-deleted" do
    category = categories(:bebidas_calientes)
    category.soft_delete!
    assert_not_includes Category.active, category
  end

  test "validates name presence" do
    category = Category.new(store: stores(:cafe_delicias))
    assert_not category.valid?
    assert category.errors[:name].any?
  end
end
