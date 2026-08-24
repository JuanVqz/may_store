class Product < ApplicationRecord
  include SoftDeletable
  include PriceCents

  belongs_to :store
  belongs_to :category
  has_many :product_components, inverse_of: :product, dependent: :destroy
  has_many :components, through: :product_components
  accepts_nested_attributes_for :product_components, allow_destroy: true, reject_if: ->(attrs) { attrs["component_id"].blank? }

  price_in_cents :base_price

  validates :name, presence: true
  validates :base_price_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :available, -> { where(available: true) }
  # The catalogue is browsed by category as often as by product, so a search for
  # "crepas" finds everything on that section of the menu.
  scope :containing, ->(term) {
    joins(:category).where("products.name ILIKE :q OR categories.name ILIKE :q", q: "%#{sanitize_sql_like(term)}%")
  }
end
