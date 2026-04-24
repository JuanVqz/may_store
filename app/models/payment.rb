class Payment < ApplicationRecord
  include PriceCents

  belongs_to :order
  belongs_to :payment_method

  price_in_cents :amount, :received

  validates :amount_cents, numericality: { greater_than: 0 }
  validate :received_cents_must_cover_amount

  def change_cents
    received_cents - amount_cents
  end

  def formatted_change
    "$#{'%.2f' % (change_cents / 100.0)}"
  end

  private

  def received_cents_must_cover_amount
    errors.add(:received_cents, :blank) if received_cents.nil?
    return if received_cents.nil? || received_cents >= amount_cents

    errors.add(:received_cents, :insufficient, amount: formatted_amount)
  end
end
