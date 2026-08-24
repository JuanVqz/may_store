class KitchenController < ApplicationController
  def index
    @line_items = LineItem.in_store(Current.store)
                          .on_the_pass
                          .includes(order: [:spot, :user], line_item_components: :component, product: :category)
                          .order(created_at: :asc, id: :asc)
  end
end
