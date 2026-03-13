class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_current_store
  before_action :set_current_user
  before_action :require_authentication

  private

  def set_current_store
    Current.store = Store.find_by!(subdomain: request.subdomain)
  rescue ActiveRecord::RecordNotFound
    render plain: I18n.t("flash.store_not_found"), status: :not_found
  end

  def set_current_user
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def require_authentication
    redirect_to login_path unless Current.user
  end

  def redirect_by_role(user)
    case user.role
    when "waiter"  then redirect_to tables_path
    when "kitchen" then redirect_to kitchen_path
    when "admin"   then redirect_to admin_dashboard_path
    end
  end
end
