# The kitchen's prep ticket for one order, as ESC/POS bytes.
#
# Mirrors the kitchen card: order meta once at the top, then items grouped by
# prep station. Product names print double-height because this ticket is read
# from across a hot line, not held in the hand like the bill.
#
# Pass a station to print only that station's items, which is what a two-printer
# setup wants (one roll at the bar, one in the kitchen).
class Receipt::KitchenTicket
  def initialize(order, station: nil)
    @order = order
    @station = station
    @line_items = order.line_items
                       .where.not(status: :cancelled)
                       .includes(line_item_components: :component, product: :category)
                       .order(created_at: :asc)
                       .to_a
    @line_items.select! { |item| item.product.category.station == station } if station
  end

  def to_escpos
    EscPos::Document.new.build do |d|
      header d
      stations d
      d.cut
    end.to_s
  end

  private

  attr_reader :order, :station, :line_items

  def header(d)
    d.center do
      d.double_size { d.text spot_label }
      d.text I18n.t("stations.#{station}") if station
    end
    d.feed
    d.row "#{I18n.t("bill.order")}:", order.code
    d.row "#{I18n.t("bill.server")}:", order.user.name
    d.row "#{I18n.t("receipt.printed_at")}:", I18n.l(Time.current, format: :time_only)
    d.rule "="
  end

  # A takeout spot is named after the counter, which tells the kitchen nothing;
  # the type is the useful label. Same rule as the kitchen card.
  def spot_label
    order.spot.takeout? ? I18n.t("spot_types.takeout") : order.spot.name
  end

  def stations(d)
    grouped = line_items.group_by { |item| item.product.category.station }

    Category.stations.keys.each do |name|
      items = grouped[name]
      next if items.blank?

      d.feed
      d.bold { d.text I18n.t("stations.#{name}").upcase } unless station
      items.each { |item| item_block d, item }
    end
  end

  # Only items still being cooked print clean. Anything already done carries its
  # status, because this ticket is printed on demand and often as a reprint: a
  # cook picking it up mid-service needs to see what is left to make, not remake
  # a latte a waiter already carried out.
  def item_block(d, item)
    d.double_height { d.text item.product.name.upcase }
    d.bold { d.text "  >> #{I18n.t("item_statuses.#{item.status}").upcase}" } unless item.cooking?
    details d, item
    d.feed
  end

  def details(d, item)
    Receipt::Components.new(item).each_label do |label|
      d.wrapped "  #{label}", indent: "    "
    end

    return if item.special_notes.blank?

    d.bold { d.wrapped "  #{I18n.t("notes").upcase}: #{item.special_notes}", indent: "    " }
  end
end
