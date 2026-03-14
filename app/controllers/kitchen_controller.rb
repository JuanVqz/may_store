class KitchenController < ApplicationController
  def index
    @line_items = LineItem
      .joins(:order)
      .where(orders: { store_id: Current.store.id })
      .where(status: [:cooking, :ready])
      .includes(order: [:spot, :user], line_item_components: :component, product: {})
      .order(created_at: :asc)
  end
end
