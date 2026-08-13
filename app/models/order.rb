class Order < ApplicationRecord
  include PriceCents
  include Order::Stateful
  include Order::CodeGenerable

  belongs_to :store
  belongs_to :spot
  belongs_to :user
  has_many :line_items, dependent: :destroy
  has_many :payments, dependent: :destroy

  scope :today, -> { where(created_at: Time.current.beginning_of_day..Time.current.end_of_day) }

  enum :status, {
    open: "open",
    cooking: "cooking",
    ready: "ready",
    delivered: "delivered",
    closed: "closed",
    cancelled: "cancelled"
  }

  price_in_cents :total

  def recalculate_total!
    update_columns(total_cents: line_items.reload.not_cancelled.sum(:total_price_cents))
  end

  def allows_item_addition?
    open? || cooking? || ready? || delivered?
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

  # "Nothing is owed". Gates close! and the bill screen. Note this is also true
  # for an order with nothing on it yet, since zero is owed on zero.
  def fully_paid?
    remaining_cents <= 0
  end

  # "Money changed hands", which is the invariant the cancel guards defend: once
  # cash is in the drawer, voiding the order strands it with nothing in the app
  # able to hand it back.
  #
  # Distinct from fully_paid?, and the two genuinely disagree in both directions:
  # an empty order owes nothing but nobody paid, and a partial payment is money
  # taken while something is still owed. Using fully_paid? here would make a
  # brand-new empty order impossible to cancel.
  #
  # `closed?` still has to be asked alongside the payment rows, because a
  # zero-total order can be closed without any payment at all.
  def payment_taken?
    closed? || payments.exists?
  end

  def readiness_counts
    if line_items.loaded?
      active = line_items.reject(&:cancelled?)
      total_count = active.size
      ready_count = active.count { |li| li.ready? || li.delivered? }
      delivered_count = active.count(&:delivered?)
    else
      rows = line_items.not_cancelled
                       .group(:status)
                       .count
      total_count = rows.values.sum
      ready_count = (rows["ready"] || 0) + (rows["delivered"] || 0)
      delivered_count = rows["delivered"] || 0
    end
    { ready: ready_count, delivered: delivered_count, total: total_count }
  end
end
