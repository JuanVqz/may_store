# Serves the customer's bill as an ESC/POS byte stream. The browser fetches it
# and forwards it to the thermal printer over WebUSB, so the response is binary
# and never rendered. See docs/references/thermal-printing.md.
class ReceiptsController < ApplicationController
  include OrderScoped
  include EscPosStreaming

  def show
    send_escpos Receipt::Bill.new(@order).to_escpos, filename: "bill-#{@order.code}"
  end
end
