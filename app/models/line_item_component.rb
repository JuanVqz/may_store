class LineItemComponent < ApplicationRecord
  include PriceCents

  belongs_to :line_item
  belongs_to :component

  enum :component_type, {
    ingredient: "ingredient",
    extra: "extra"
  }

  price_in_cents :unit_price

  PORTION_LABELS = {
    0.0 => "portions.none",
    0.25 => "portions.quarter",
    0.5 => "portions.half",
    0.75 => "portions.three_quarters",
    1.0 => "portions.full"
  }.freeze

  validates :line_item_id, :component_id, :component_type, presence: true
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :portion, inclusion: { in: [0.0, 0.25, 0.5, 0.75, 1.0] }

  def portion_label
    I18n.t(PORTION_LABELS[portion.to_f] || "portions.full")
  end
end
