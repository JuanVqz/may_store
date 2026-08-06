class ProductComponent < ApplicationRecord
  belongs_to :product
  belongs_to :component

  enum :component_type, {
    ingredient: "ingredient",
    extra: "extra"
  }

  validates :component_id, :component_type, presence: true

  scope :ordered, -> { order(:position) }
end
