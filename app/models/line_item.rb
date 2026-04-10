class LineItem < ApplicationRecord
  include PriceCents
  include LineItem::Stateful

  belongs_to :order
  belongs_to :product
  belongs_to :ready_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  belongs_to :delivered_by, class_name: "User", optional: true
  has_many :line_item_components, dependent: :destroy

  enum :status, {
    ordering: "ordering",
    cooking: "cooking",
    ready: "ready",
    delivered: "delivered",
    cancelled: "cancelled"
  }

  after_save :recalculate_order_total, if: :saved_change_to_total_price_cents?
  after_destroy :recalculate_order_total

  price_in_cents :base_price, :total_price

  def calculate_total!
    extras_total = line_item_components
                     .where(component_type: :extra)
                     .sum(:unit_price_cents)
    self.total_price_cents = base_price_cents + extras_total
    save!
  end

  private

  def recalculate_order_total
    order.recalculate_total!
  end
end
