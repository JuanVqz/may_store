# Voiding a single item off an order.
#
# Each refusal gets its own message: "already paid" and "already delivered" ask
# the cashier for completely different next steps, so collapsing both into one
# generic alert leaves them guessing which one they hit.
class LineItems::CancellationsController < ApplicationController
  include LineItemScoped

  def create
    @line_item.cancel!(by: Current.user)
    redirect_back fallback_location: order_path(@order), notice: t("kitchen.item_cancelled")
  rescue LineItem::Stateful::OrderPaid
    redirect_back fallback_location: order_path(@order), alert: t("line_item.cannot_cancel_paid")
  rescue LineItem::Stateful::InvalidTransition
    redirect_back fallback_location: order_path(@order),
                  alert: t("line_item.cannot_cancel_status", status: @line_item.status_label.downcase)
  end
end
