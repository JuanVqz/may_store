class CashClosing < ApplicationRecord
  include PriceCents

  belongs_to :store
  belongs_to :user
  has_many :cash_closing_lines, dependent: :destroy

  accepts_nested_attributes_for :cash_closing_lines

  scope :recent, -> { order(period_start: :desc, created_at: :desc) }

  enum :status, {
    open: "open",
    closed: "closed"
  }

  validates :period_start, presence: true
  validates :period_end, presence: true

  price_in_cents :total_expected, :total_actual, :total_difference

  # The corte covers the whole day. Stores keep different hours (06:00-22:00 for
  # one, 08:00-16:00 for another), so no fixed window is right for all of them,
  # and the calendar day is the boundary they do share. Per-store opening hours
  # would refine this and change nothing else.
  #
  # A second corte on the same day reuses the day's open one rather than starting
  # a rival count of the same money.
  def self.open_for_today!(store:, user:)
    period = Time.current.all_day

    closing = where(store: store, period_start: period.begin, period_end: period.end)
                .find_by(status: :open)
    closing ||= create!(
      store: store, user: user, status: :open,
      period_start: period.begin, period_end: period.end
    )

    closing.calculate_expected!
    closing
  end

  def status_label
    I18n.t("cash_closing_statuses.#{status}")
  end

  def period_label
    "#{I18n.l(period_start.to_date)} #{I18n.l(period_start, format: :time_only)} - #{I18n.l(period_end, format: :time_only)}"
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
