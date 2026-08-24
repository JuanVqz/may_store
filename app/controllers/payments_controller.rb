class PaymentsController < ApplicationController
  include OrderScoped

  def create
    return redirect_to order_path(@order) if @order.closed? || @order.fully_paid?

    @order.settle!(payment_method: payment_method, received_cents: parse_cents(params[:received]))
    redirect_to order_path(@order), notice: t("order.closed")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to order_bill_path(@order), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def payment_method
    Current.store.payment_methods.find(params[:payment_method_id])
  end

  # The cashier types pesos; the column stores cents.
  def parse_cents(value)
    (value.to_f * 100).round if value.present?
  end
end
