module LineItem::Customizable
  extend ActiveSupport::Concern

  # What the customer asked for on top of the product itself: how much of each
  # ingredient, and which extras, priced.
  #
  # Both arrive keyed by component id, the way the customization form posts
  # them, so a caller never has to look product components up itself. Portions
  # default to a full one, since an ingredient the form did not mention is the
  # product as the kitchen normally makes it.
  def customize!(portions: {}, extras: {})
    transaction do
      add_ingredients(portions)
      add_extras(extras)
      calculate_total!
    end

    self
  end

  private

  def add_ingredients(portions)
    product.product_components.ingredient.includes(:component).each do |pc|
      line_item_components.create!(
        component: pc.component,
        component_type: :ingredient,
        portion: (portions[pc.component_id.to_s].presence || 1.0).to_f,
        unit_price_cents: 0
      )
    end
  end

  # An extra can be asked for more than once ("double bacon"), so a quantity
  # becomes that many rows: there is deliberately no unique index on the join,
  # and each row carries the price it was sold at.
  def add_extras(quantities)
    return if quantities.blank?

    extras = product.product_components.extra.includes(:component).index_by(&:component_id)

    quantities.each do |component_id, quantity|
      component = extras[component_id.to_i]&.component
      next unless component

      quantity.to_i.times do
        line_item_components.create!(
          component: component,
          component_type: :extra,
          portion: 1.0,
          unit_price_cents: component.price_cents
        )
      end
    end
  end
end
