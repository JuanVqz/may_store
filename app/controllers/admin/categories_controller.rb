class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: [:edit, :update, :destroy]

  def index
    @categories = Current.store.categories.active.ordered
  end

  def new
    @category = Current.store.categories.new
  end

  def create
    @category = Current.store.categories.new(category_params)
    if @category.save
      redirect_to admin_categories_path, notice: t("admin.categories.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: t("admin.categories.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.soft_delete!
    redirect_to admin_categories_path, notice: t("admin.categories.deleted")
  end

  private

  def set_category
    @category = Current.store.categories.active.find(params[:id])
  end

  def category_params
    params.expect(category: [:name])
  end
end
