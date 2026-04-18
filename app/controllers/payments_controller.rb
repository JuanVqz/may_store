class PaymentsController < ApplicationController
  def create
    @order = Current.store.orders.find(params[:order_id])

    if @order.closed? || @order.fully_paid?
      redirect_to order_path(@order) and return
    end

    payment_method = Current.store.payment_methods.find(params[:payment_method_id])

    Payment.transaction do
      @order.payments.create!(
        payment_method: payment_method,
        amount_cents: @order.remaining_cents,
        paid_at: Time.current
      )
      @order.close!
    end

    redirect_to order_path(@order), notice: t("order.closed")
  end
end
