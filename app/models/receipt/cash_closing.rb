# The daily cash count, as ESC/POS bytes, to be signed and dropped in the drawer.
#
# Expected, counted and difference cannot sit in one row: three money columns
# plus a payment method name exceed the 42 columns the roll gives us, and the
# printer would break the numbers mid-digit. So each method gets a small block
# instead, which also leaves room for a long method name.
class Receipt::CashClosing
  def initialize(cash_closing)
    @cash_closing = cash_closing
    @lines = cash_closing.cash_closing_lines.includes(:payment_method).to_a
  end

  def to_escpos
    EscPos::Document.new.build do |d|
      header d
      methods d
      totals d
      notes d
      signature d
      d.cut
    end.to_s
  end

  private

  attr_reader :cash_closing, :lines

  def header(d)
    d.center do
      d.double_size { d.text cash_closing.store.name }
      d.text I18n.t("cash_closing.title")
    end
    d.feed
    d.text "#{I18n.t("cash_closing.period")}:"
    d.wrapped "  #{cash_closing.period_label}", indent: "  "
    d.row "#{I18n.t("cash_closing.performed_by")}:", cash_closing.user.name

    # A closed corte is dated by when it was closed; an open one is a snapshot,
    # so it is dated by when it came off the printer.
    if cash_closing.closed?
      d.row "#{I18n.t("cash_closing.status_closed")}:", I18n.l(cash_closing.closed_at, format: :short)
    else
      d.row "#{I18n.t("receipt.printed_at")}:", I18n.l(Time.current, format: :short)
    end

    d.rule "="
  end

  def methods(d)
    lines.each do |line|
      d.feed
      d.bold { d.text line.payment_method.name.upcase }
      d.row "  #{I18n.t("cash_closing.expected")}", line.formatted_expected
      d.row "  #{I18n.t("cash_closing.actual")}", line.formatted_actual
      d.row "  #{I18n.t("cash_closing.difference")}", signed(line.difference_cents)
    end
  end

  def totals(d)
    d.feed
    d.rule "="
    d.row I18n.t("cash_closing.expected").upcase, cash_closing.formatted_total_expected
    d.row I18n.t("cash_closing.actual").upcase, cash_closing.formatted_total_actual
    d.bold { d.row I18n.t("cash_closing.difference").upcase, signed(cash_closing.total_difference_cents) }
    d.rule "="
  end

  def notes(d)
    return if cash_closing.notes.blank?

    d.feed
    d.text "#{I18n.t("cash_closing.notes")}:"
    d.wrapped "  #{cash_closing.notes}", indent: "  "
  end

  # Somewhere to sign, which is the point of printing this at all.
  def signature(d)
    d.feed 2
    d.text "  #{I18n.t("cash_closing.signature")}: ____________________"
  end

  # A shortfall and a surplus read very differently to whoever counts the
  # drawer, so the sign is explicit rather than implied by a minus.
  def signed(cents)
    return "$0.00" if cents.zero?

    sign = cents.negative? ? "-" : "+"
    "#{sign}$#{"%.2f" % (cents.abs / 100.0)}"
  end
end
