class TablesController < ApplicationController
  def index
    @spots = Current.store.spots.tables.where(active: true).order(:position)
    @active_orders = Current.store.orders
                            .where.not(status: [:closed, :cancelled])
                            .includes(:line_items)
                            .index_by(&:spot_id)
  end
end
