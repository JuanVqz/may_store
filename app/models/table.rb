class Table < ApplicationRecord
  belongs_to :store
  has_many :orders

  validates :name, presence: true, uniqueness: { scope: :store_id }
end
