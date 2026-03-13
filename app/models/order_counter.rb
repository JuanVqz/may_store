class OrderCounter < ApplicationRecord
  belongs_to :store

  validates :year_month, presence: true, uniqueness: { scope: :store_id }
end
