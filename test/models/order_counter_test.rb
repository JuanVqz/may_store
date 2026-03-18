require "test_helper"

class OrderCounterTest < ActiveSupport::TestCase
  test "unique constraint on store_id + year_month" do
    existing = order_counters(:cafe_march)
    duplicate = OrderCounter.new(
      store: existing.store,
      year_month: existing.year_month,
      current_sequence: 0
    )
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
