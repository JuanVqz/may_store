class PaymentsController < ApplicationController
  def create
    @order = Current.store.orders.find(params[:order_id])

    if @order.closed? || @order.fully_paid?
      redirect_to order_path(@order) and return
    end

    payment_method = Current.store.payment_methods.find(params[:payment_method_id])
    received_cents = parse_cents(params[:received])

    # Auto-fill received_cents for non-cash payments
    is_cash = payment_method.name.downcase == "efectivo"
    if received_cents.nil? || received_cents == 0
      received_cents = @order.remaining_cents unless is_cash
    end

    Payment.transaction do
      @order.payments.create!(
        payment_method: payment_method,
        amount_cents: @order.remaining_cents,
        received_cents: received_cents,
        paid_at: Time.current
      )
      @order.close!
    end

    redirect_to order_path(@order), notice: t("order.closed")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to bill_order_path(@order), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def parse_cents(value)
    return nil if value.blank?
    (value.to_f * 100).round
  end
end
