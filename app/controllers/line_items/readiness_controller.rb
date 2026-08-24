# The kitchen saying an item is cooked.
class LineItems::ReadinessController < ApplicationController
  include LineItemScoped

  def create
    @line_item.mark_ready!(by: Current.user)
    redirect_back fallback_location: order_path(@order), notice: t("kitchen.marked_ready")
  rescue LineItem::Stateful::InvalidTransition => e
    redirect_back fallback_location: order_path(@order), alert: e.message
  end
end
