class Payment < ApplicationRecord
  include PriceCents

  belongs_to :order
  belongs_to :payment_method

  price_in_cents :amount

  validates :amount_cents, numericality: { greater_than: 0 }
end
