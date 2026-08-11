# The one-line-per-component description of a line item, shared by every
# receipt.
#
# The bill and the kitchen ticket print the same facts at different indents, and
# both used to carry their own copy of the partition-and-group rule. That put
# "extras with the same component_id collapse to xN" in three places counting
# line_items/_components.html.erb, so a change to how extras are described could
# leave the bill, the ticket and the screen disagreeing about one order.
class Receipt::Components
  def initialize(line_item)
    @line_item = line_item
  end

  # Ingredients first (every one, so a new cook reads the full recipe), then
  # extras collapsed by component. Special notes are not included: each receipt
  # styles them differently, and the kitchen ticket bolds them.
  def each_label
    return enum_for(:each_label) unless block_given?

    ingredients, extras = @line_item.line_item_components.partition(&:ingredient?)

    ingredients.each do |component|
      yield "#{component.component.name}: #{component.portion_label}"
    end

    extras.group_by(&:component_id).each_value do |group|
      yield "+ #{group.first.component.name} x#{group.size}"
    end
  end
end
