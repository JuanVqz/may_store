class TakeoutsController < ApplicationController
  def index
    @spot = Spot.takeout_for(Current.store)
    @orders = @spot.orders
                   .where.not(status: [:closed, :cancelled])
                   .order(created_at: :desc)
  end
end
