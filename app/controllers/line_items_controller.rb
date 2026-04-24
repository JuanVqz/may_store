class LineItemsController < ApplicationController
  rescue_from LineItem::InvalidTransition, with: :handle_invalid_transition

  before_action :set_order
  before_action :set_line_item, only: [:destroy, :ready, :deliver, :cancel]

  def new
    @product = Current.store.products.find(params[:product_id])
    @ingredients = @product.product_components.ingredient.ordered.includes(:component)
    @extras = @product.product_components.extra.ordered.includes(:component)

    render partial: "line_items/customization_form", locals: { product: @product, ingredients: @ingredients, extras: @extras, order: @order }
  end

  def create
    product = Current.store.products.find(line_item_params[:product_id])
    notes = params[:special_notes].presence

    if @order.open?
      @line_item = @order.line_items.create!(
        product: product,
        status: :ordering,
        base_price_cents: product.base_price_cents,
        special_notes: notes
      )
    else
      @line_item = @order.add_item!(product: product, special_notes: notes)
    end

    build_components(@line_item, product)
    @line_item.calculate_total!
    @order.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to order_path(@order), notice: t("order.item_added") }
    end
  end

  def destroy
    @line_item.destroy!
    @order.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to order_path(@order) }
    end
  end

  def ready
    @line_item.mark_ready!(by: Current.user)
    redirect_back fallback_location: order_path(@order), notice: t("kitchen.marked_ready")
  end

  def deliver
    @line_item.mark_delivered!(by: Current.user)
    redirect_back fallback_location: order_path(@order), notice: t("line_item.marked_delivered")
  end

  def cancel
    @line_item.cancel!(by: Current.user)
    redirect_back fallback_location: order_path(@order), notice: t("kitchen.item_cancelled")
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

    extra_params = (params[:extras]&.to_unsafe_h || {}).select { |_, qty| qty.to_i > 0 }
    if extra_params.any?
      component_ids = extra_params.keys.map(&:to_i)
      components_by_id = Current.store.components.where(id: component_ids).index_by(&:id)

      extra_params.each do |component_id, quantity|
        component = components_by_id[component_id.to_i]
        next unless component

        quantity.to_i.times do
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

  def handle_invalid_transition(exception)
    redirect_back fallback_location: order_path(@order), alert: exception.message
  end
end
