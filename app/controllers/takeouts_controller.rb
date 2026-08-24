class TakeoutsController < ApplicationController
  def index
    @spot = Spot.takeout_for(Current.store)
    @orders = @spot.orders.in_progress.includes(:line_items).order(created_at: :desc)
  end
end
