class LineItemsController < ApplicationController
  include OrderScoped

  before_action :set_line_item, only: [:update, :destroy]

  def new
    @product = Current.store.products.find(params[:product_id])
    @ingredients = @product.product_components.ingredient.ordered.includes(:component)
    @extras = @product.product_components.extra.ordered.includes(:component)

    render partial: "line_items/customization_form", locals: { product: @product, ingredients: @ingredients, extras: @extras, order: @order }
  end

  def create
    product = Current.store.products.find(line_item_params[:product_id])
    notes = special_notes_param

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

  # Correcting why an item was cancelled. Cancelling records a default so the
  # waiter never has to stop and think, which only pays off if the guess can be
  # put right afterwards; this is that path.
  # The reason only means anything on a cancelled item, and the route is not
  # protected by the view hiding the form: a stale or hand-made PATCH would
  # otherwise stamp "kitchen_error" on an item that was cooked and served, and
  # any grouping by reason would count it.
  def update
    unless @line_item.cancelled?
      return redirect_back fallback_location: order_path(@order),
                           alert: t("line_item.reason_only_when_cancelled")
    end

    if @line_item.update(line_item_update_params)
      redirect_back fallback_location: order_path(@order), notice: t("line_item.reason_updated")
    else
      redirect_back fallback_location: order_path(@order),
                    alert: @line_item.errors.full_messages.to_sentence
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

  private

  def set_line_item
    @line_item = @order.line_items.find(params[:id])
  end

  def line_item_params
    params.require(:line_item).permit(:product_id)
  end

  # Only the reason: everything else about a line item is driven by its own
  # actions, not by editing the record.
  def line_item_update_params
    params.expect(line_item: [:cancellation_reason])
  end

  def special_notes_param
    params.permit(:special_notes)[:special_notes].presence
  end

  def ingredient_portions
    params.permit(ingredients: {}).to_h.fetch("ingredients", {})
  end

  def extra_quantities
    params.permit(extras: {}).to_h.fetch("extras", {}).select { |_, qty| qty.to_i > 0 }
  end

  def build_components(line_item, product)
    product.product_components.ingredient.includes(:component).each do |pc|
      portion = ingredient_portions[pc.component_id.to_s].presence || 1.0
      LineItemComponent.create!(
        line_item: line_item,
        component: pc.component,
        component_type: :ingredient,
        portion: portion.to_f,
        unit_price_cents: 0
      )
    end

    if extra_quantities.any?
      extras_by_component_id = product.product_components.extra.includes(:component).index_by(&:component_id)

      extra_quantities.each do |component_id, quantity|
        pc = extras_by_component_id[component_id.to_i]
        next unless pc

        quantity.to_i.times do
          LineItemComponent.create!(
            line_item: line_item,
            component: pc.component,
            component_type: :extra,
            portion: 1.0,
            unit_price_cents: pc.component.price_cents
          )
        end
      end
    end
  end
end
