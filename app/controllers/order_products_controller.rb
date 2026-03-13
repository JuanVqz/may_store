class OrderProductsController < ApplicationController
  before_action :set_order

  def index
    @categories = Current.store.categories.active.ordered
    @category =
      if params[:category_id]
        Current.store.categories.find(params[:category_id])
      else
        @categories.first
      end
    @products = @category&.products&.active&.available || Product.none
  end

  private

  def set_order
    @order = Current.store.orders.find(params[:order_id])
  end
end
