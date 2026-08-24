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

  test "open_order joins the order already on a table" do
    spot = spots(:mesa_1)
    existing = spot.orders.in_progress.first

    assert_equal existing, spot.open_order(user: users(:waiter_juan))
  end

  test "open_order opens one on a table with nothing on it" do
    spot = spots(:mesa_2)

    order = spot.open_order(user: users(:waiter_juan))

    assert order.open?
    assert_equal spot, order.spot
    assert_equal users(:waiter_juan), order.user
  end

  # Several takeout orders wait side by side, so there is no "the" order on that
  # spot to join.
  test "open_order always starts a new takeout order" do
    spot = Spot.takeout_for(stores(:cafe_delicias))
    first = spot.open_order(user: users(:waiter_juan))

    assert_not_equal first, spot.open_order(user: users(:waiter_juan))
  end

  test "a closed order no longer holds its table" do
    spot = spots(:mesa_2)
    order = spot.open_order(user: users(:waiter_juan))
    order.update!(status: :closed, closed_at: Time.current)

    assert_not_equal order, spot.open_order(user: users(:waiter_juan))
  end

  # Tables that already carry two live orders exist, because until now every tap
  # opened one. Joining the older of them puts the waiter back on the bill the
  # guests have been running.
  test "open_order joins the oldest live order on a table" do
    spot = spots(:mesa_2)
    older = spot.open_order(user: users(:waiter_juan))
    newer = spot.orders.create!(store: spot.store, user: users(:waiter_juan),
                                status: :open, opened_at: Time.current)
    older.update_columns(created_at: 20.minutes.ago)

    assert_equal older, spot.open_order(user: users(:waiter_juan))
    assert_not_equal newer, spot.open_order(user: users(:waiter_juan))
  end
end
