# Serves an order's kitchen prep ticket as an ESC/POS byte stream.
#
# `station` narrows the ticket to one prep area, which is what a two-printer
# setup wants: the bar roll prints only bar items, the kitchen roll only kitchen
# items. Without it the whole order prints on one ticket.
class KitchenTicketsController < ApplicationController
  include OrderScoped
  include EscPosStreaming

  def show
    ticket = Receipt::KitchenTicket.new(@order, station: station)

    send_escpos ticket.to_escpos, filename: ["ticket", @order.code, station].compact.join("-")
  end

  private

  # An unknown station would silently print an empty ticket, so it is dropped
  # and the whole order prints instead.
  def station
    params[:station].presence_in(Category.stations.keys)
  end
end
