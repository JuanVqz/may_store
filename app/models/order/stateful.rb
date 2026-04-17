module Order::Stateful
  extend ActiveSupport::Concern

  included do
    after_update_commit :broadcast_refreshes, if: :saved_change_to_status?
  end

  STATUS_COLORS = {
    "open" => "#FCD34D",
    "cooking" => "#F97316",
    "ready" => "#22C55E",
    "delivered" => "#A855F7",
    "closed" => "#6B7280",
    "cancelled" => "#EF4444"
  }.freeze

  def status_label
    I18n.t("order_statuses.#{status}")
  end

  def status_color
    STATUS_COLORS[status]
  end

  def confirm!
    return unless open?
    raise ActiveRecord::RecordInvalid, self if line_items.empty?

    transaction do
      update!(status: :cooking, cooking_at: Time.current)
      line_items.where(status: :ordering).update_all(status: :cooking)
    end

    broadcast_refresh_to "store_#{store_id}_kitchen"
  end

  def check_ready!
    return unless cooking?
    return cancel! if line_items.where.not(status: :cancelled).none?

    unfinished = line_items.where.not(status: [:ready, :delivered, :cancelled]).exists?
    update!(status: :ready, ready_at: Time.current) unless unfinished
  end

  def check_delivered!
    return unless ready?
    return cancel! if line_items.where.not(status: :cancelled).none?

    unfinished = line_items.where.not(status: [:delivered, :cancelled]).exists?
    update!(status: :delivered, delivered_at: Time.current) unless unfinished
  end

  def close!
    raise ActiveRecord::RecordInvalid, self unless fully_paid?
    update!(status: :closed, closed_at: Time.current)
  end

  def cancel!
    transaction do
      update!(status: :cancelled, cancelled_at: Time.current)
      line_items.where(status: [:ordering, :cooking, :ready])
                .update_all(status: :cancelled)
    end
  end

  private

  def broadcast_refreshes
    broadcast_refresh_to "order_#{id}"
    broadcast_refresh_to "store_#{store_id}_tables"
    broadcast_refresh_to "store_#{store_id}_takeouts"
  end
end
