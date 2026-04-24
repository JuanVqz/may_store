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
    if line_items.loaded?
      active = line_items.reject(&:cancelled?)
      total_count = active.size
      ready_count = active.count { |li| li.ready? || li.delivered? }
      delivered_count = active.count(&:delivered?)
    else
      rows = line_items.where.not(status: :cancelled)
                       .group(:status)
                       .count
      total_count = rows.values.sum
      ready_count = (rows["ready"] || 0) + (rows["delivered"] || 0)
      delivered_count = rows["delivered"] || 0
    end
    { ready: ready_count, delivered: delivered_count, total: total_count }
  end
end
