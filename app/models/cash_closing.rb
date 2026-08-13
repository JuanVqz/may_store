class CashClosing < ApplicationRecord
  include PriceCents

  belongs_to :store
  belongs_to :user
  has_many :cash_closing_lines, dependent: :destroy
  # The payments this corte claimed when it closed. No `dependent:`, because a
  # corte is a record of a count and is never destroyed; if one ever were, the
  # payments would have to survive it to be counted by a later corte.
  has_many :payments

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
  # The reuse is a read followed by a create, which two simultaneous requests can
  # both pass (a double-tapped button, two tabs, two devices). A partial unique
  # index on the open ones is what actually holds the invariant, so a loser of that
  # race lands here as RecordNotUnique and reuses the corte that won instead.
  def self.open_current!(store:, user:)
    closing = where(store: store).find_by(status: :open)

    closing ||= begin
      create!(
        store: store, user: user, status: :open,
        period_start: next_period_start_for(store), period_end: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      where(store: store).find_by!(status: :open)
    end

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

  # Every method the corte will actually claim money on needs a line, not just the
  # active ones: deactivating a method after taking money on it used to leave that
  # money claimed by the corte and shown in no line at all, so it was counted by
  # nobody, forever. Lines already on the corte are recomputed too, so a method
  # deactivated mid-corte cannot keep a stale expected that the total still sums.
  #
  # Active methods with no payments still get a line, since a cashier confirming
  # "nothing came in on this one" is part of counting the drawer.
  def calculate_expected!
    totals = countable_payments.group(:payment_method_id).sum(:amount_cents)
    method_ids = store.payment_methods.active.ids | totals.keys | cash_closing_lines.pluck(:payment_method_id)

    PaymentMethod.where(id: method_ids).each do |pm|
      line = cash_closing_lines.find_or_initialize_by(payment_method: pm)
      line.expected_cents = totals[pm.id] || 0
      line.save!
    end

    # find_or_initialize_by works on fresh instances, so a caller that preloaded
    # cash_closing_lines would otherwise keep rendering the expected amounts from
    # before this recalculation, while the SQL totals showed the new ones.
    cash_closing_lines.reset
  end

  # An open corte counts every payment no corte has claimed yet; a closed one
  # counts exactly what it claimed, so its totals never move again.
  #
  # Membership is by claim, not by timestamp. Selecting on paid_at would drop a
  # payment written with a paid_at inside an already-closed period: too late for
  # the corte that covered that time, too early for the next one.
  #
  # Deliberately not filtered by order status. A Payment row means money reached
  # the drawer, and the drawer does not care whether the food was served: an
  # order cancelled after being paid keeps its payments (cancel! does not touch
  # them), and filtering those out left that money counted by no corte at all.
  # A partial payment on an order still open counts for the same reason: the
  # money is in the till now.
  #
  # The gap this leaves is refunds, which the app cannot express yet. Handing
  # money back is invisible here, so a refunded payment still reads as cash on
  # hand. See docs/plans/in_progress/26-08-11-corte-de-caja.md.
  def countable_payments
    scope = Payment.joins(:order).where(orders: { store_id: store_id })

    closed? ? scope.where(cash_closing: self) : scope.uncounted
  end

  def total_expected_cents
    cash_closing_lines.sum(:expected_cents)
  end

  # Whether anyone has entered a physical count yet. An untouched open corte has a
  # difference of minus the whole drawer, which reads as a shortfall instead of as
  # a count nobody has done.
  def counted?
    closed? || cash_closing_lines.where.not(actual_cents: 0).exists?
  end

  def total_actual_cents
    cash_closing_lines.sum(:actual_cents)
  end

  def total_difference_cents
    cash_closing_lines.sum(:difference_cents)
  end

  # Closing takes one last reading, claims the payments it counted, and freezes.
  # The claim is what makes the count final: those payments now belong to this
  # corte and no later one can count them again.
  #
  # All three in one transaction, because a claim without a matching set of
  # totals, or totals without the claim, would silently miscount the next corte.
  #
  # The claim happens *before* the totals are read, and the totals are then read
  # from the claim itself. Reading first and claiming second left a gap: under
  # READ COMMITTED a payment the register committed between the two statements was
  # claimed by this corte yet excluded from its frozen totals, and being claimed
  # it was then invisible to every later corte too.
  def close!
    transaction do
      update!(period_end: Time.current)
      claimed = countable_payments.update_all(cash_closing_id: id, updated_at: Time.current)
      update!(status: :closed, closed_at: Time.current)
      calculate_expected!
      claimed
    end
  end
end
