class LineItem < ApplicationRecord
  include PriceCents

  belongs_to :order
  belongs_to :product
  has_many :line_item_components, dependent: :destroy

  enum :status, {
    ordering: "ordering",
    cooking: "cooking",
    ready: "ready",
    delivered: "delivered",
    cancelled: "cancelled"
  }

  STATUS_COLORS = {
    "ordering" => "#FCD34D",
    "cooking" => "#F97316",
    "ready" => "#22C55E",
    "delivered" => "#A855F7",
    "cancelled" => "#EF4444"
  }.freeze

  after_update :check_order_status, if: :saved_change_to_status?
  after_save :recalculate_order_total, if: :saved_change_to_total_price_cents?
  after_destroy :recalculate_order_total

  price_in_cents :base_price, :total_price

  def status_label
    I18n.t("item_statuses.#{status}")
  end

  def status_color
    STATUS_COLORS[status]
  end

  def calculate_total!
    extras_total = line_item_components
                     .where(component_type: :extra)
                     .sum(:unit_price_cents)
    self.total_price_cents = base_price_cents + extras_total
    save!
  end

  def mark_ready!
    update!(status: :ready)
  end

  def mark_delivered!
    update!(status: :delivered)
  end

  def cancel!
    update!(status: :cancelled)
  end

  private

  def check_order_status
    order.check_ready!
    order.check_delivered!
  end

  def recalculate_order_total
    order.recalculate_total!
  end
end
