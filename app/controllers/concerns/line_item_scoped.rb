# The line item, found through its order, which is itself found through the
# current store. Two hops, both scoped, so neither id can cross a tenant.
module LineItemScoped
  extend ActiveSupport::Concern
  include OrderScoped

  included do
    before_action :set_line_item
  end

  private

  def set_line_item
    @line_item = @order.line_items.find(params[:line_item_id])
  end
end
