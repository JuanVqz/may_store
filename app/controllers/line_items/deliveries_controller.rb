# The waiter saying an item reached the table.
class LineItems::DeliveriesController < ApplicationController
  include LineItemScoped

  def create
    @line_item.mark_delivered!(by: Current.user)
    redirect_back fallback_location: order_path(@order), notice: t("line_item.marked_delivered")
  rescue LineItem::Stateful::InvalidTransition => e
    redirect_back fallback_location: order_path(@order), alert: e.message
  end
end
