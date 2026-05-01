class Admin::PaymentMethodsController < Admin::BaseController
  before_action :set_payment_method, only: [:edit, :update, :destroy]

  def index
    @payment_methods = Current.store.payment_methods.order(:name)
  end

  def new
    @payment_method = Current.store.payment_methods.new
  end

  def create
    @payment_method = Current.store.payment_methods.new(payment_method_params)
    if @payment_method.save
      redirect_to admin_payment_methods_path, notice: t("admin.payment_methods.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment_method.update(payment_method_params)
      redirect_to admin_payment_methods_path, notice: t("admin.payment_methods.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payment_method.destroy
    redirect_to admin_payment_methods_path, notice: t("admin.payment_methods.deleted")
  end

  private

  def set_payment_method
    @payment_method = Current.store.payment_methods.find(params[:id])
  end

  def payment_method_params
    params.expect(payment_method: [:name, :active])
  end
end
