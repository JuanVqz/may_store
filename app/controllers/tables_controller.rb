class TablesController < ApplicationController
  def index
    @spots = Current.store.spots.tables.active.order(:position)
    @active_orders = Current.store.orders.in_progress.includes(:line_items).index_by(&:spot_id)
  end
end
