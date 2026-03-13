class ProductComponent < ApplicationRecord
  belongs_to :product
  belongs_to :component

  enum :component_type, {
    ingredient: "ingredient",
    extra: "extra"
  }

  scope :ordered, -> { order(:position) }
end
