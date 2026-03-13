class Component < ApplicationRecord
  include SoftDeletable
  include PriceCents

  belongs_to :store
  has_many :product_components, dependent: :destroy

  price_in_cents :price

  validates :name, presence: true

  scope :available, -> { where(available: true) }
  scope :ingredients, -> { where(price_cents: 0) }
  scope :extras, -> { where("price_cents > 0") }
end
