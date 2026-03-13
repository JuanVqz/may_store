class CashClosingLine < ApplicationRecord
  include PriceCents

  belongs_to :cash_closing
  belongs_to :payment_method

  price_in_cents :expected, :actual, :difference

  before_save :calculate_difference

  private

  def calculate_difference
    self.difference_cents = (actual_cents || 0) - (expected_cents || 0)
  end
end
