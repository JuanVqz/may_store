class Store < ApplicationRecord
  has_many :users
  has_many :spots
  has_many :categories
  has_many :components
  has_many :products
  has_many :orders
  has_many :payment_methods
  has_many :cash_closings
  has_many :order_counters

  normalizes :subdomain, with: -> { it.strip.downcase }
  normalizes :order_prefix, with: -> { it.strip.upcase }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true
  validates :order_prefix, presence: true, uniqueness: true, length: { maximum: 5 }
end
