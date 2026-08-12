module LineItem::Stateful
  extend ActiveSupport::Concern

  class InvalidTransition < StandardError; end

  # Its own class so callers can tell the two refusals apart: one is about this
  # item's status, the other about money already taken for the whole order. They
  # deserve different messages, since "already delivered" and "already paid" ask
  # the user for different next steps.
  class OrderPaid < InvalidTransition; end

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

  # Cancelling an item on a paid order would recalculate the order's total
  # downwards and leave it overpaid, with the difference sitting in the drawer
  # and no way to refund it. Reachable in practice: paying before the food is
  # delivered leaves items READY on an order that is already closed.
  #
  # The item's own status is checked first so an already-delivered item reports
  # that, rather than blaming the payment for a refusal that would have happened
  # anyway.
  def cancel!(by: nil)
    raise LineItem::Stateful::InvalidTransition, "Cannot cancel #{status} items" if cancelled? || delivered?
    raise LineItem::Stateful::OrderPaid, "Cannot cancel items on an order that has been paid" if order.payment_taken?

    update!(status: :cancelled, cancelled_by: by)
  end

  # What the views ask before offering a cancel button, so the rule lives here with
  # cancel! instead of being spelled out at every call site. cancel! still raises
  # rather than consulting this, because each refusal needs to say which rule it
  # hit; keep the two in step.
  def cancellable?
    !cancelled? && !delivered? && !order.payment_taken?
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
