require "test_helper"

# A session is only as good as the user behind it. Soft-deleting an employee has
# to end their access, at login and mid-session, and a session must never be
# valid for a store other than the one it was created on.
class SessionLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @other_store = stores(:mi_cafe)
    @user = users(:waiter_juan)
    @account = accounts(:waiter_juan_account)
  end

  test "a soft-deleted user cannot log in" do
    @user.soft_delete!

    post login_url(subdomain: @store.subdomain),
      params: { employee_number: @account.employee_number, password: PASSWORD }

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("login.error")
    assert_nil session[:user_id]
  end

  test "an active user can still log in" do
    log_in

    assert_redirected_to root_url(subdomain: @store.subdomain)
    assert_equal @user.id, session[:user_id]
  end

  test "soft-deleting a user ends their session on the next request" do
    log_in
    @user.soft_delete!

    get tables_url(subdomain: @store.subdomain)

    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "a session that no longer resolves is cleared, not re-checked forever" do
    log_in
    @user.soft_delete!

    get tables_url(subdomain: @store.subdomain)

    assert_nil session[:user_id]
  end

  test "a deactivated user cannot log in" do
    @user.update!(active: false)

    log_in

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "deactivating a user ends their session on the next request" do
    log_in
    @user.update!(active: false)

    get tables_url(subdomain: @store.subdomain)

    assert_redirected_to login_url(subdomain: @store.subdomain)
    assert_nil session[:user_id]
  end

  # Host-only session cookies keep a cafe cookie from ever reaching pizza, so
  # the cookie has to be planted by hand for this to exercise the store scope in
  # set_current_user rather than the absence of a cookie.
  test "a session does not carry across stores when the cookie reaches the other host" do
    log_in
    planted = raw_session_cookie

    get tables_url(subdomain: @other_store.subdomain), headers: { "HTTP_COOKIE" => planted }

    assert_redirected_to login_url(subdomain: @other_store.subdomain)
  end

  # Session fixation: without reset_session a cookie planted before login (which
  # a sibling subdomain can do the moment the session cookie is not host-only)
  # would still name the session the user logs in to.
  test "logging in rotates the session id" do
    post login_url(subdomain: @store.subdomain),
      params: { employee_number: @account.employee_number, password: "wrong" }
    before = session.id.to_s

    log_in

    assert_not_empty before
    assert_not_equal before, session.id.to_s
  end

  private

  def log_in
    post login_url(subdomain: @store.subdomain),
      params: { employee_number: @account.employee_number, password: PASSWORD }
  end

  # The `name=value` pair as sent on the wire, so it can be replayed against a
  # host the cookie jar would never send it to.
  def raw_session_cookie
    key = Rails.application.config.session_options[:key]
    set_cookie = response.headers["set-cookie"] || response.headers["Set-Cookie"]

    Array(set_cookie).flat_map { |header| header.split("\n") }
                     .find { |cookie| cookie.start_with?("#{key}=") }
                     &.split(";")
                     &.first
  end
end
