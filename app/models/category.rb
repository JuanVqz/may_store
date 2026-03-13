class Category < ApplicationRecord
  include SoftDeletable

  belongs_to :store
  has_many :products

  validates :name, presence: true

  scope :ordered, -> { order(:position) }
end
