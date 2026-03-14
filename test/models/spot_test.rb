require "test_helper"

class SpotTest < ActiveSupport::TestCase
  test "validates name uniqueness per store" do
    existing = spots(:mesa_1)
    duplicate = Spot.new(store: existing.store, name: existing.name, spot_type: :dine_in)
    assert_not duplicate.valid?
  end

  test "validates name presence" do
    spot = Spot.new(store: stores(:cafe_delicias), spot_type: :dine_in)
    assert_not spot.valid?
    assert spot.errors[:name].any?
  end

  test "validates spot_type presence" do
    spot = Spot.new(store: stores(:cafe_delicias), name: "Test")
    spot.spot_type = nil
    assert_not spot.valid?
  end

  test "tables scope returns only table spots" do
    tables = Spot.tables
    assert tables.all?(&:dine_in?)
  end

  test "takeouts scope returns only takeout spots" do
    takeouts = Spot.takeouts
    assert takeouts.all?(&:takeout?)
  end

  test "takeout_for creates takeout spot if none exists" do
    store = stores(:cafe_delicias)
    # Remove existing takeout fixture
    Spot.where(store: store, spot_type: :takeout).delete_all

    assert_difference "Spot.count", 1 do
      spot = Spot.takeout_for(store)
      assert spot.takeout?
      assert_equal I18n.t("spot_types.takeout"), spot.name
    end
  end

  test "takeout_for returns existing takeout spot" do
    store = stores(:cafe_delicias)
    existing = spots(:para_llevar)

    assert_no_difference "Spot.count" do
      spot = Spot.takeout_for(store)
      assert_equal existing, spot
    end
  end
end
