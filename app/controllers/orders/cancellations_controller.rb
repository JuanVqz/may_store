# Voiding a whole order and freeing its table.
class Orders::CancellationsController < ApplicationController
  include OrderScoped

  def create
    if @order.cancel!
      redirect_to tables_path, notice: t("order.table_available", name: @order.spot.name)
    else
      redirect_to order_path(@order), alert: t("order.cannot_cancel_paid")
    end
  end
end
