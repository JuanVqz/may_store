class Order < ApplicationRecord
  include PriceCents
  include Order::Stateful
  include Order::CodeGenerable

  belongs_to :store
  belongs_to :spot
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

  price_in_cents :total

  def recalculate_total!
    update_columns(total_cents: line_items.reload.where.not(status: :cancelled).sum(:total_price_cents))
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
    broadcast_refresh_to "store_#{store_id}_kitchen"
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

  def readiness_counts
    active = line_items.where.not(status: :cancelled)
    total_count = active.count
    ready_count = active.where(status: [:ready, :delivered]).count
    delivered_count = active.where(status: :delivered).count
    { ready: ready_count, delivered: delivered_count, total: total_count }
  end
end
