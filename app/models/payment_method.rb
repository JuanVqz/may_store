class PaymentMethod < ApplicationRecord
  belongs_to :store
  has_many :payments

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
