class Admin::SpotsController < Admin::BaseController
  before_action :set_spot, only: [:edit, :update, :destroy]

  def index
    @spots = Current.store.spots.order(:spot_type, :name)
  end

  def new
    @spot = Current.store.spots.new
  end

  def create
    @spot = Current.store.spots.new(spot_params)
    if @spot.save
      redirect_to admin_spots_path, notice: t("admin.spots.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @spot.update(spot_params)
      redirect_to admin_spots_path, notice: t("admin.spots.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @spot.destroy
    redirect_to admin_spots_path, notice: t("admin.spots.deleted")
  end

  private

  def set_spot
    @spot = Current.store.spots.find(params[:id])
  end

  def spot_params
    params.expect(spot: [:name, :spot_type, :active])
  end
end
