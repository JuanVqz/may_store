class Admin::ComponentsController < Admin::BaseController
  before_action :set_component, only: [:edit, :update, :destroy]

  def index
    scope = Current.store.components.active.order(:name)
    scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    @pagy, @components = pagy(scope)
  end

  def new
    @component = Current.store.components.new
  end

  def create
    @component = Current.store.components.new(component_params)
    if @component.save
      redirect_to admin_components_path, notice: t("admin.components.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @component.update(component_params)
      redirect_to admin_components_path, notice: t("admin.components.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @component.soft_delete!
    redirect_to admin_components_path, notice: t("admin.components.deleted")
  end

  private

  def set_component
    @component = Current.store.components.active.find(params[:id])
  end

  def component_params
    params.expect(component: [:name, :price, :available])
  end
end
