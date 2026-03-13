class TablesController < ApplicationController
  def index
    @tables = Current.store.tables.where(active: true).order(:position)
    @active_orders = Current.store.orders
                            .where.not(status: [:closed, :cancelled])
                            .index_by(&:table_id)
  end
end
