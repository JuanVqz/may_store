class TakeoutsController < ApplicationController
  def index
    @spot = Spot.takeout_for(Current.store)
    @orders = @spot.orders
                   .where.not(status: [:closed, :cancelled])
                   .includes(:line_items)
                   .order(created_at: :desc)
  end
end
