class OrdersController < ApplicationController
  before_action :set_order, only: [:show]

  def index
    @orders = Current.store.orders.today.includes(:spot, :user, :line_items).order(created_at: :desc)
  end

  def create
    spot = Current.store.spots.find(params[:spot_id])

    redirect_to order_path(spot.open_order(user: Current.user))
  end

  def show
    @line_items = @order.line_items
                       .not_cancelled
                       .includes(:product, line_item_components: :component)
                       .order(created_at: :desc)

    # The closed screen is a receipt, so it lists items the way the printed bill
    # does: oldest first and cancelled ones included. Handing it @line_items
    # (newest first, cancelled dropped) numbered the same order differently on
    # screen and on paper, so "line #2" meant two different products.
    if @order.closed?
      @receipt_items = @order.line_items
                            .includes(:product, line_item_components: :component)
                            .order(created_at: :asc)
    end

    load_menu if @order.allows_item_addition?
  end

  private

  def set_order
    @order = Current.store.orders.find(params[:id])
  end

  # The menu the waiter picks from, one category at a time. A store with no
  # categories yet has nothing to show, which is why @category can be nil.
  def load_menu
    @categories = Current.store.categories.active.ordered
    @category = params[:category_id] ? Current.store.categories.find(params[:category_id]) : @categories.first
    @products = @category ? @category.products.active.available.includes(product_components: :component) : Product.none
  end
end
