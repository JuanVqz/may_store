class PaymentMethod < ApplicationRecord
  belongs_to :store
  has_many :payments, dependent: :restrict_with_error

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
