class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :confirm, :cancel]

  def new
    @table = Current.store.tables.find(params[:table_id])
    @order = Current.store.orders.create!(
      table: @table,
      user: Current.user,
      status: :open,
      opened_at: Time.current
    )
    redirect_to order_products_path(@order)
  end

  def show
    @line_items = @order.line_items.includes(:product, :line_item_components)
  end

  def confirm
    @order.confirm!
    redirect_to order_path(@order), notice: t("order.confirmed")
  end

  def cancel
    @order.cancel!
    redirect_to tables_path, notice: t("order.table_available", name: @order.table.name)
  end

  private

  def set_order
    @order = Current.store.orders.find(params[:id])
  end
end
