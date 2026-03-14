require "test_helper"

class TableTest < ActiveSupport::TestCase
  test "validates name uniqueness per store" do
    existing = tables(:mesa_1)
    duplicate = Table.new(store: existing.store, name: existing.name)
    assert_not duplicate.valid?
  end

  test "validates name presence" do
    table = Table.new(store: stores(:cafe_delicias))
    assert_not table.valid?
    assert table.errors[:name].any?
  end
end
