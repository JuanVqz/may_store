class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [:new, :create]
  layout "login", only: [:new, :create]

  def new
  end

  def create
    account = Account.joins(:user)
                     .where(users: { store_id: Current.store.id })
                     .find_by(employee_number: params[:employee_number])

    if account&.authenticate(params[:password])
      session[:user_id] = account.user_id
      redirect_by_role(account.user)
    else
      flash.now[:alert] = I18n.t("login.error")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: I18n.t("login.logged_out")
  end
end
