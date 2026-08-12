# The printed corte de caja, as an ESC/POS byte stream, on the same transport as
# the bills and kitchen tickets.
class Admin::CashClosingReceiptsController < Admin::BaseController
  include EscPosStreaming

  # An open corte is refreshed before printing, the same as viewing it. The paper
  # is the artifact that gets signed and filed, so it is the last place that should
  # carry whatever number the previous screen happened to leave behind.
  def show
    closing = Current.store.cash_closings.find(params[:cash_closing_id])
    closing.refresh_expected!

    send_escpos Receipt::CashClosing.new(closing).to_escpos,
                filename: "corte-#{closing.period_start.to_date.iso8601}"
  end
end
