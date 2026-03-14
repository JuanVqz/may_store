class LineItem < ApplicationRecord
  include PriceCents

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
  after_update_commit :broadcast_item_update, if: :saved_change_to_status?

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

  def mark_ready!(by: nil)
    raise InvalidTransition, "Can only mark cooking items as ready" unless cooking?
    update!(status: :ready, ready_by: by)
  end

  def mark_delivered!(by: nil)
    raise InvalidTransition, "Can only deliver ready items" unless ready?
    update!(status: :delivered, delivered_by: by)
  end

  def cancel!(by: nil)
    raise InvalidTransition, "Cannot cancel #{status} items" if cancelled? || delivered?
    update!(status: :cancelled, cancelled_by: by)
  end

  class InvalidTransition < StandardError; end

  def broadcast_kitchen_update
    kitchen_channel = "store_#{order.store_id}_kitchen"

    case status
    when "cooking"
      broadcast_append_to kitchen_channel,
        target: "kitchen-queue",
        partial: "kitchen/line_item_card",
        locals: { item: self }
    when "ready"
      broadcast_replace_to kitchen_channel,
        target: "kitchen_line_item_#{id}",
        partial: "kitchen/line_item_card",
        locals: { item: self }
    when "cancelled", "delivered"
      broadcast_remove_to kitchen_channel,
        target: "kitchen_line_item_#{id}"
    end

    broadcast_kitchen_queue_count
  end

  def broadcast_kitchen_queue_count
    store_id = order.store_id
    count = LineItem.joins(:order)
      .where(orders: { store_id: store_id })
      .where(status: [:cooking, :ready])
      .count

    broadcast_replace_to "store_#{store_id}_kitchen",
      target: "kitchen-queue-count",
      html: "<span id=\"kitchen-queue-count\">#{I18n.t('kitchen.queue_count', count: count)}</span>"
  end

  private

  def broadcast_item_update
    broadcast_replace_to "order_#{order_id}",
      target: "line_item_#{id}",
      partial: "line_items/line_item",
      locals: { item: self, order: order }

    broadcast_kitchen_update
    broadcast_spot_update
  end

  def broadcast_spot_update
    o = order
    broadcast_replace_to "store_#{o.store_id}_tables",
      target: "spot_#{o.spot_id}",
      partial: "tables/table",
      locals: { spot: o.spot, order: o }

    if o.spot.takeout?
      broadcast_replace_to "store_#{o.store_id}_takeouts",
        target: "takeout_order_#{o.id}",
        partial: "takeouts/order_card",
        locals: { order: o }
    end
  end

  def check_order_status
    order.check_ready!
    order.check_delivered!
  end

  def recalculate_order_total
    order.recalculate_total!
  end
end
