require "test_helper"

# The login page renders flash messages through the toaster component, which
# auto-dismisses after five seconds. That makes a browser-level assertion on the
# message text inherently racy, so the message itself is asserted here against
# the rendered response instead.
#
# Regression guard: the login layout used to pass `toast_flash_messages` to the
# toaster as a block, but the component takes a `content:` local and never
# yields, so every flash on the login page was silently dropped.
class LoginFlashTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
  end

  test "a failed login renders the error message" do
    post login_url(subdomain: @store.subdomain),
      params: { employee_number: accounts(:waiter_juan_account).employee_number, password: "wrong" }

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("login.error")
  end

  test "an unknown employee number renders the error message" do
    post login_url(subdomain: @store.subdomain),
      params: { employee_number: "NOPE-999", password: PASSWORD }

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("login.error")
  end

  test "signing out renders the signed out message on the login page" do
    post login_url(subdomain: @store.subdomain),
      params: { employee_number: accounts(:waiter_juan_account).employee_number,
                password: PASSWORD }
    delete logout_url(subdomain: @store.subdomain)

    follow_redirect!

    assert_includes response.body, I18n.t("login.logged_out")
  end
end
