class CashClosing < ApplicationRecord
  include PriceCents

  belongs_to :store
  belongs_to :user
  has_many :cash_closing_lines, dependent: :destroy

  enum :status, {
    open: "open",
    closed: "closed"
  }

  validates :period_start, presence: true
  validates :period_end, presence: true

  price_in_cents :total_expected, :total_actual, :total_difference

  def status_label
    I18n.t("cash_closing_statuses.#{status}")
  end

  def calculate_expected!
    store.payment_methods.active.each do |pm|
      expected = Payment.joins(:order)
                        .where(orders: { store_id: store_id, status: :closed })
                        .where(payment_method: pm)
                        .where(paid_at: period_start..period_end)
                        .sum(:amount_cents)

      line = cash_closing_lines.find_or_initialize_by(payment_method: pm)
      line.expected_cents = expected
      line.save!
    end
  end

  def total_expected_cents
    cash_closing_lines.sum(:expected_cents)
  end

  def total_actual_cents
    cash_closing_lines.sum(:actual_cents)
  end

  def total_difference_cents
    cash_closing_lines.sum(:difference_cents)
  end

  def close!
    update!(status: :closed, closed_at: Time.current)
  end
end
