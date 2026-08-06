class Admin::ProductsController < Admin::BaseController
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  def index
    scope = Current.store.products.active.joins(:category).includes(:category).order(:name)
    if params[:q].present?
      q = "%#{params[:q]}%"
      scope = scope.where("products.name ILIKE ? OR categories.name ILIKE ?", q, q)
    end
    @pagy, @products = pagy(scope)
  end

  def show
  end

  def new
    @product = Current.store.products.new
    @product.product_components.build
  end

  def create
    @product = Current.store.products.new(product_params)
    if @product.save
      redirect_to admin_products_path, notice: t("admin.products.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to admin_products_path, notice: t("admin.products.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.soft_delete!
    redirect_to admin_products_path, notice: t("admin.products.deleted")
  end

  private

  def set_product
    @product = Current.store.products.active.includes(:product_components, :components).find(params[:id])
  end

  def product_params
    params.expect(
      product: [
        :name, :base_price, :category_id, :available,
        product_components_attributes: [[:id, :component_id, :component_type, :_destroy]]
      ]
    )
  end
end
