class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :confirm, :cancel, :bill]

  def index
    @orders = Current.store.orders.today.includes(:spot, :user, :line_items).order(created_at: :desc)
  end

  def create
    @spot = Current.store.spots.find(params[:spot_id])
    @order = Current.store.orders.create!(
      spot: @spot,
      user: Current.user,
      status: :open,
      opened_at: Time.current
    )
    redirect_to order_path(@order)
  end

  def show
    @line_items = @order.line_items
                       .where.not(status: :cancelled)
                       .includes(:product, line_item_components: :component)
                       .order(created_at: :desc)

    if @order.open? || @order.cooking? || @order.ready? || @order.delivered?
      @categories = Current.store.categories.active.ordered
      @category =
        if params[:category_id]
          Current.store.categories.find(params[:category_id])
        else
          @categories.first
        end
      @products = @category&.products&.active&.available&.includes(:product_components) || Product.none
    end
  end

  def confirm
    if @order.line_items.empty?
      redirect_to order_path(@order), alert: t("order.no_items")
      return
    end

    @order.confirm!
    redirect_to order_path(@order), notice: t("order.confirmed")
  end

  def cancel
    @order.cancel!
    redirect_to tables_path, notice: t("order.table_available", name: @order.spot.name)
  end

  def bill
    if @order.closed? || @order.fully_paid?
      redirect_to order_path(@order) and return
    end

    @line_items = @order.line_items
                       .includes(:product, line_item_components: :component)
                       .order(created_at: :asc)
    @payment_methods = Current.store.payment_methods.active.order(:name)
  end

  private

  def set_order
    @order = Current.store.orders.find(params[:id])
  end
end
