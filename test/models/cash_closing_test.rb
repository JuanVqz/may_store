require "test_helper"

class CashClosingTest < ActiveSupport::TestCase
  test "status enum" do
    closing = cash_closings(:open_closing)
    assert closing.open?
    closing.update!(status: :closed, closed_at: Time.current)
    assert closing.closed?
  end

  test "total helpers sum from cash_closing_lines" do
    closing = cash_closings(:open_closing)
    expected_sum = closing.cash_closing_lines.sum(:expected_cents)
    assert_equal expected_sum, closing.total_expected_cents

    actual_sum = closing.cash_closing_lines.sum(:actual_cents)
    assert_equal actual_sum, closing.total_actual_cents

    diff_sum = closing.cash_closing_lines.sum(:difference_cents)
    assert_equal diff_sum, closing.total_difference_cents
  end
end
