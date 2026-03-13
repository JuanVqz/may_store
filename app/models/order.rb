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

  price_in_cents :total

  def status_label
    I18n.t("order_statuses.#{status}")
  end

  def status_color
    STATUS_COLORS[status]
  end

  def recalculate_total!
    update_columns(total_cents: line_items.where.not(status: :cancelled).sum(:total_price_cents))
  end

  def confirm!
    transaction do
      update!(status: :cooking, cooking_at: Time.current)
      line_items.where(status: :ordering).update_all(status: :cooking)
    end
  end

  def check_ready!
    return unless cooking?
    unfinished = line_items.where.not(status: [:ready, :delivered, :cancelled]).exists?
    update!(status: :ready, ready_at: Time.current) unless unfinished
  end

  def check_delivered!
    return unless ready?
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

  def add_item!(product:, components_params: [], special_notes: nil)
    update!(status: :cooking) if ready?

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

  def generate_code
    return if code.present?

    prefix = store.order_prefix
    year_month = Time.current.strftime("%y%m")

    counter = OrderCounter.find_or_create_by!(store_id: store_id, year_month: year_month) do |c|
      c.current_sequence = 0
    end

    OrderCounter.where(id: counter.id)
                .update_all("current_sequence = current_sequence + 1")
    counter.reload

    self.code = "#{prefix}#{year_month}-#{counter.current_sequence.to_s.rjust(3, '0')}"
  end
end
