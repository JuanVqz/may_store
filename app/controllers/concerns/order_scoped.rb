# Every controller that acts on an order finds it the same way: through the
# current store, so an order id from another tenant is a 404 and not a leak.
module OrderScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_order
  end

  private

  def set_order
    @order = Current.store.orders.find(params[:order_id])
  end
end
