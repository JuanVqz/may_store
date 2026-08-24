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

  # Scoped to the store and to employable users, so soft-deleting or
  # deactivating an employee ends their session on the next request instead of
  # when they get around to logging out. The store scope also keeps a session
  # from carrying across subdomains if the session cookie ever stops being
  # host-only. Spelled out rather than using the `active` scope, which
  # SoftDeletable defines as `deleted_at: nil` and says nothing about the
  # `active` column.
  def set_current_user
    return unless session[:user_id]

    Current.user = Current.store.users.where(active: true, deleted_at: nil).find_by(id: session[:user_id])
    session.delete(:user_id) unless Current.user
  end

  def require_authentication
    redirect_to login_path unless Current.user
  end

  # A role is a default screen, not a set of permissions: the kitchen starts on
  # the queue, everyone else on the floor. Any of them can go anywhere from
  # there.
  def redirect_by_role(user)
    redirect_to user.kitchen? ? kitchen_path : root_path
  end
end
