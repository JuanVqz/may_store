class LineItemsController < ApplicationController
  before_action :set_order
  before_action :set_line_item, only: [:destroy, :ready, :deliver]

  def new
    @product = Current.store.products.find(params[:product_id])
    @ingredients = @product.product_components.ingredient.ordered.includes(:component)
    @extras = @product.product_components.extra.ordered.includes(:component)
  end

  def create
    product = Current.store.products.find(line_item_params[:product_id])

    if @order.open?
      @line_item = @order.line_items.create!(
        product: product,
        status: :ordering,
        base_price_cents: product.base_price_cents
      )
    else
      @line_item = @order.add_item!(product: product)
    end

    build_components(@line_item, product)
    @line_item.calculate_total!

    redirect_to order_products_path(@order), notice: t("order.item_added")
  end

  def destroy
    @line_item.destroy!
    redirect_to order_path(@order)
  end

  def ready
    @line_item.mark_ready!
    redirect_to order_path(@order), notice: t("kitchen.marked_ready")
  end

  def deliver
    @line_item.mark_delivered!
    redirect_to order_path(@order), notice: t("line_item.marked_delivered")
  end

  private

  def set_order
    @order = Current.store.orders.find(params[:order_id])
  end

  def set_line_item
    @line_item = @order.line_items.find(params[:id])
  end

  def line_item_params
    params.require(:line_item).permit(:product_id)
  end

  def build_components(line_item, product)
    # Build ingredients from params or defaults
    product.product_components.ingredient.includes(:component).each do |pc|
      portion = params.dig(:ingredients, pc.component_id.to_s).presence || 1.0
      LineItemComponent.create!(
        line_item: line_item,
        component: pc.component,
        component_type: :ingredient,
        portion: portion.to_f,
        unit_price_cents: 0
      )
    end

    # Build extras from params
    (params[:extras] || {}).each do |component_id, quantity|
      qty = quantity.to_i
      next if qty <= 0

      component = Current.store.components.find(component_id)
      qty.times do
        LineItemComponent.create!(
          line_item: line_item,
          component: component,
          component_type: :extra,
          portion: 1.0,
          unit_price_cents: component.price_cents
        )
      end
    end
  end
end
