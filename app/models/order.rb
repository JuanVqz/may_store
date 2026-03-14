class Order < ApplicationRecord
  include PriceCents

  belongs_to :store
  belongs_to :table
  belongs_to :user
  has_many :line_items, dependent: :destroy
  has_many :payments, dependent: :destroy

  enum :status, {
    open: "open",
    cooking: "cooking",
    ready: "ready",
    delivered: "delivered",
    closed: "closed",
    cancelled: "cancelled"
  }

  STATUS_COLORS = {
    "open" => "#FCD34D",
    "cooking" => "#F97316",
    "ready" => "#22C55E",
    "delivered" => "#A855F7",
    "closed" => "#6B7280",
    "cancelled" => "#EF4444"
  }.freeze

  before_create :generate_code
  after_update_commit :broadcast_order_update, if: :saved_change_to_status?

  price_in_cents :total

  def status_label
    I18n.t("order_statuses.#{status}")
  end

  def status_color
    STATUS_COLORS[status]
  end

  def recalculate_total!
    update_columns(total_cents: line_items.reload.where.not(status: :cancelled).sum(:total_price_cents))
  end

  def confirm!
    raise ActiveRecord::RecordInvalid, self if line_items.empty?

    transaction do
      update!(status: :cooking, cooking_at: Time.current)
      line_items.where(status: :ordering).update_all(status: :cooking)
    end
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
    update!(status: :closed, closed_at: Time.current)
  end

  def cancel!
    transaction do
      update!(status: :cancelled, cancelled_at: Time.current)
      line_items.where(status: [:ordering, :cooking, :ready])
                .update_all(status: :cancelled)
    end
  end

  def add_item!(product:, special_notes: nil)
    update!(status: :cooking) if ready? || delivered?

    item = line_items.create!(
      product: product,
      status: :cooking,
      base_price_cents: product.base_price_cents,
      special_notes: special_notes
    )
    item.calculate_total!
    item
  end

  def total_paid_cents
    payments.sum(:amount_cents)
  end

  def remaining_cents
    total_cents - total_paid_cents
  end

  def fully_paid?
    remaining_cents <= 0
  end

  private

  def broadcast_order_update
    broadcast_replace_to "order_#{id}",
      target: "order_header",
      partial: "orders/order_header",
      locals: { order: self }

    broadcast_replace_to "order_#{id}",
      target: "order_summary",
      partial: "orders/order_summary",
      locals: { order: self }

    # Broadcast each line item to update action buttons (e.g., after confirm, items switch to cooking)
    line_items.includes(:product, line_item_components: :component).each do |item|
      broadcast_replace_to "order_#{id}",
        target: "line_item_#{item.id}",
        partial: "line_items/line_item",
        locals: { item: item, order: self }
    end

    broadcast_replace_to "store_#{store_id}_tables",
      target: "table_#{table_id}",
      partial: "tables/table",
      locals: { table: table, order: self }
  end

  def generate_code
    return if code.present?

    prefix = store.order_prefix
    year_month = Time.current.strftime("%y%m")

    begin
      OrderCounter.find_or_create_by!(store_id: store_id, year_month: year_month) do |c|
        c.current_sequence = 0
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    sql = OrderCounter.sanitize_sql_array([
      "UPDATE order_counters SET current_sequence = current_sequence + 1, updated_at = NOW() " \
      "WHERE store_id = ? AND year_month = ? RETURNING current_sequence",
      store_id, year_month
    ])
    seq = OrderCounter.connection.select_value(sql)

    self.code = "#{prefix}#{year_month}-#{seq.to_s.rjust(3, '0')}"
  end
end
