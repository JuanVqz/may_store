module LineItem::Stateful
  extend ActiveSupport::Concern

  class InvalidTransition < StandardError; end

  included do
    after_save :check_order_status, if: :saved_change_to_status?
    after_save_commit :broadcast_refreshes, if: :saved_change_to_status?
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
    raise LineItem::Stateful::InvalidTransition, "Can only mark cooking items as ready" unless cooking?
    update!(status: :ready, ready_by: by)
  end

  def mark_delivered!(by: nil)
    raise LineItem::Stateful::InvalidTransition, "Can only deliver ready items" unless ready?
    update!(status: :delivered, delivered_by: by)
  end

  # Cancelling an item on a closed order would recalculate the order's total
  # downwards and leave it overpaid, with the difference sitting in the drawer
  # and no way to refund it. Reachable in practice: paying before the food is
  # delivered leaves items READY on an order that is already closed.
  def cancel!(by: nil)
    raise LineItem::Stateful::InvalidTransition, "Cannot cancel items on a closed order" if order.closed?
    raise LineItem::Stateful::InvalidTransition, "Cannot cancel #{status} items" if cancelled? || delivered?

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
