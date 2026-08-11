# The customer's bill, as ESC/POS bytes for the thermal printer.
#
# Mirrors orders/bill.html.erb: same fields, same order, same money. It is a
# separate renderer rather than a print stylesheet on that view because the
# printer takes bytes, not HTML. See docs/references/thermal-printing.md.
class Receipt::Bill
  def initialize(order)
    @order = order
    @line_items = order.line_items
                       .includes(:product, line_item_components: :component)
                       .order(created_at: :asc)
  end

  def to_escpos
    EscPos::Document.new.build do |d|
      header d
      items d
      totals d
      footer d
      d.cut
    end.to_s
  end

  private

  attr_reader :order, :line_items

  def header(d)
    d.center do
      d.double_size { d.text order.store.name }
      d.text I18n.t("bill.title")
    end
    d.feed
    d.row "#{I18n.t("bill.table")}:", order.spot.name
    d.row "#{I18n.t("bill.order")}:", order.code
    d.row "#{I18n.t("bill.date")}:", I18n.l(order.created_at, format: :short)
    d.row "#{I18n.t("bill.server")}:", order.user.name
    d.rule "="
  end

  def items(d)
    line_items.each_with_index do |item, index|
      label = "##{index + 1} #{item.product.name}"

      if item.cancelled?
        d.row label, I18n.t("bill.cancelled")
      else
        d.row label, item.formatted_total_price
      end
      details d, item
    end
  end

  # Ingredient portions and extras explain what the customer is paying for, so
  # they belong on the bill even though they carry no price of their own.
  def details(d, item)
    Receipt::Components.new(item).each_label do |label|
      d.wrapped "    #{label}", indent: "      "
    end

    d.wrapped "    #{item.special_notes}", indent: "      " if item.special_notes.present?
  end

  def totals(d)
    d.rule
    d.bold { d.row I18n.t("bill.total").upcase, order.formatted_total }

    return if order.payments.empty?

    d.feed
    order.payments.each { |payment| payment_block d, payment }
    d.row I18n.t("receipt.remaining"), money(order.remaining_cents) if order.remaining_cents.positive?
  end

  # What the customer handed over and what they got back. Only cash needs the
  # received/change pair: the cashier counts the drawer against it and a customer
  # disputing the change has the arithmetic in their hand. On a card or transfer
  # the received amount is the total by definition, so printing it is noise.
  #
  # The amount is only worth a line when payments are split, otherwise it just
  # repeats TOTAL two lines above.
  def payment_block(d, payment)
    d.row I18n.t("receipt.paid_with"), payment.payment_method.name
    d.row I18n.t("receipt.amount"), payment.formatted_amount if order.payments.size > 1

    return unless payment.payment_method.cash?

    d.row I18n.t("bill.received"), payment.formatted_received
    d.row I18n.t("bill.change"), payment.formatted_change
  end

  # Order exposes remaining_cents as a computed method, so there is no
  # PriceCents-generated formatter for it.
  def money(cents)
    "$#{"%.2f" % (cents / 100.0)}"
  end

  def footer(d)
    d.rule "="
    d.feed
    d.center do
      d.text I18n.t("receipt.thanks")
      d.barcode order.code
    end
  end
end
