# The cashier's register screen for an order: what is owed and how it is being
# paid. A bill is a view of the order, so it reads as a nested resource rather
# than as a custom action on the order.
class Orders::BillsController < ApplicationController
  include OrderScoped

  def show
    return redirect_to order_path(@order) if @order.closed? || @order.fully_paid?

    @line_items = @order.line_items
                        .includes(:product, line_item_components: :component)
                        .order(created_at: :asc)
    @payment_methods = Current.store.payment_methods.active.order(:name)
  end
end
