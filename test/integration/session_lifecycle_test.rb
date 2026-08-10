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

  test "a session does not carry across stores" do
    log_in

    get tables_url(subdomain: @other_store.subdomain)

    assert_redirected_to login_url(subdomain: @other_store.subdomain)
  end

  private

  def log_in
    post login_url(subdomain: @store.subdomain),
      params: { employee_number: @account.employee_number, password: PASSWORD }
  end
end
