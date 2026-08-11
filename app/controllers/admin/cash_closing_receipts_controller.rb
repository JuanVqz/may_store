# The printed corte de caja, as an ESC/POS byte stream, on the same transport as
# the bills and kitchen tickets.
class Admin::CashClosingReceiptsController < Admin::BaseController
  include EscPosStreaming

  def show
    closing = Current.store.cash_closings.find(params[:cash_closing_id])

    send_escpos Receipt::CashClosing.new(closing).to_escpos,
                filename: "corte-#{closing.period_start.to_date.iso8601}"
  end
end
