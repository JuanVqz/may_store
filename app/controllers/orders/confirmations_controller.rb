# Confirming an order sends it to the kitchen. A confirmation is a thing that
# happens to an order once, so it is created, not patched onto the order.
class Orders::ConfirmationsController < ApplicationController
  include OrderScoped

  def create
    @order.confirm!
    redirect_to order_path(@order), notice: t("order.confirmed")
  rescue ActiveRecord::RecordInvalid
    redirect_to order_path(@order), alert: t("order.no_items")
  rescue Order::Stateful::InvalidTransition
    redirect_to order_path(@order), alert: t("order.cannot_confirm_status", status: @order.status_label.downcase)
  end
end
