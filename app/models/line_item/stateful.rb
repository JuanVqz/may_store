module LineItem::Stateful
  extend ActiveSupport::Concern

  included do
    after_update :check_order_status, if: :saved_change_to_status?
    after_update_commit :broadcast_refreshes, if: :saved_change_to_status?
  end

  STATUS_COLORS = {
    "ordering" => "#FCD34D",
    "cooking" => "#F97316",
    "ready" => "#22C55E",
    "delivered" => "#A855F7",
    "cancelled" => "#EF4444"
  }.freeze

  def status_label
    I18n.t("item_statuses.#{status}")
  end

  def status_color
    STATUS_COLORS[status]
  end

  def mark_ready!(by: nil)
    raise LineItem::InvalidTransition, "Can only mark cooking items as ready" unless cooking?
    update!(status: :ready, ready_by: by)
  end

  def mark_delivered!(by: nil)
    raise LineItem::InvalidTransition, "Can only deliver ready items" unless ready?
    update!(status: :delivered, delivered_by: by)
  end

  def cancel!(by: nil)
    raise LineItem::InvalidTransition, "Cannot cancel #{status} items" if cancelled? || delivered?
    update!(status: :cancelled, cancelled_by: by)
  end

  private

  def broadcast_refreshes
    broadcast_refresh_to "order_#{order_id}"
    broadcast_refresh_to "store_#{order.store_id}_kitchen"
    broadcast_refresh_to "store_#{order.store_id}_tables"
    broadcast_refresh_to "store_#{order.store_id}_takeouts"
  end

  def check_order_status
    order.check_ready!
    order.check_delivered!
  end
end
