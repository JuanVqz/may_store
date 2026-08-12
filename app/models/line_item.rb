class LineItem < ApplicationRecord
  include PriceCents
  include LineItem::Stateful

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

  # Why an item was cancelled. Without it, "the customer changed their mind",
  # "the kitchen made it wrong" and "we had run out" are indistinguishable
  # afterwards, even though the second is waste the store paid for and the third
  # is a stock problem.
  #
  # `validate:` rather than the default so a value outside the list fails
  # validation instead of raising ArgumentError on assignment, which a stale or
  # tampered form post would otherwise turn into a 500. Same reasoning as
  # Category#station. `allow_nil` because items cancelled before this existed
  # have none, and that has to stay a legal state.
  enum :cancellation_reason, {
    customer_changed_mind: "customer_changed_mind",
    kitchen_error: "kitchen_error",
    out_of_stock: "out_of_stock",
    duplicate: "duplicate"
  }, prefix: :reason, validate: { allow_nil: true }

  # Assumed when nobody says otherwise. It is both the most common case and the
  # safest to guess wrong: it understates waste rather than inventing an
  # accusation against the kitchen.
  DEFAULT_CANCELLATION_REASON = "customer_changed_mind".freeze

  # Cancelling changes no price, but the order total excludes cancelled items,
  # so a status change into or out of cancelled has to recompute it too.
  # Without that, the bill keeps charging for a cancelled item.
  after_save :recalculate_order_total, if: :affects_order_total?
  after_destroy :recalculate_order_total

  price_in_cents :base_price, :total_price

  def cancellation_reason_label
    I18n.t("cancellation_reasons.#{cancellation_reason}") if cancellation_reason
  end

  def calculate_total!
    extras_total = line_item_components
                     .where(component_type: :extra)
                     .sum(:unit_price_cents)
    self.total_price_cents = base_price_cents + extras_total
    save!
  end

  private

  def affects_order_total?
    saved_change_to_total_price_cents? || saved_change_to_status&.include?("cancelled")
  end

  def recalculate_order_total
    order.recalculate_total!
  end
end
