class Payment < ApplicationRecord
  include PriceCents

  belongs_to :order
  belongs_to :payment_method

  # The corte de caja that counted this payment, set when that corte is closed.
  # Nil means the money has not been counted yet, which is what the next corte
  # picks up. Deliberately not selected by time: a payment written with a paid_at
  # inside an already-closed period would fall between two cortes and be counted
  # by neither.
  belongs_to :cash_closing, optional: true

  scope :uncounted, -> { where(cash_closing_id: nil) }

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
