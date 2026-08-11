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

  # Cortes chain: one picks up exactly where the last one was closed and runs to
  # the moment it is closed itself. So a store can cut the drawer as often as it
  # likes (per shift, per cashier, twice on a busy Saturday) and no sale is ever
  # counted twice or missed between two cortes.
  #
  # Only one corte is open at a time, which is what keeps that true: a second
  # open corte would overlap the first and count the same money twice, so an
  # existing open one is reused rather than rivalled.
  def self.open_current!(store:, user:)
    closing = where(store: store).find_by(status: :open)
    closing ||= create!(
      store: store, user: user, status: :open,
      period_start: next_period_start_for(store), period_end: Time.current
    )

    closing.refresh_expected!
    closing
  end

  # Where an unstarted corte begins: the end of the last closed one, or, for a
  # store's first ever corte, its earliest payment, so nothing that was sold is
  # left uncounted.
  def self.next_period_start_for(store)
    last_closed = where(store: store, status: :closed).order(period_end: :desc).first
    return last_closed.period_end if last_closed

    earliest_payment_at(store) || Time.current.beginning_of_day
  end

  def self.earliest_payment_at(store)
    Payment.joins(:order).where(orders: { store_id: store.id }).minimum(:paid_at)
  end

  # An open corte runs to "now", so its expected totals move as sales land. Both
  # the end of the period and the totals are refreshed together, since one is
  # meaningless without the other.
  def refresh_expected!
    return if closed?

    update!(period_end: Time.current)
    calculate_expected!
  end

  def status_label
    I18n.t("cash_closing_statuses.#{status}")
  end

  # A corte can span midnight or last ten minutes, so both ends carry their date
  # unless they fall on the same day.
  def period_label
    if period_start.to_date == period_end.to_date
      "#{I18n.l(period_start.to_date)} #{I18n.l(period_start, format: :time_only)} - #{I18n.l(period_end, format: :time_only)}"
    else
      "#{I18n.l(period_start, format: :short)} - #{I18n.l(period_end, format: :short)}"
    end
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

  # Closing fixes the period's end at this moment and takes one last reading, so
  # a sale rung up while the drawer was being counted still lands in this corte
  # rather than falling into the gap before the next one.
  def close!
    refresh_expected!
    update!(status: :closed, closed_at: Time.current)
  end
end
