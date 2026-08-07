require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "waiter signs in and lands on the home screen" do
    sign_in_waiter

    assert_current_path root_path
    assert_text stores(:cafe_delicias).name
  end

  test "kitchen user signs in and lands on the kitchen queue" do
    sign_in_kitchen

    assert_current_path kitchen_path
    assert_text I18n.t("kitchen.oldest_first")
  end

  test "admin signs in and can reach the admin area" do
    sign_in_admin

    assert_current_path root_path

    click_on I18n.t("admin.nav.title")

    assert_current_path admin_root_path
    assert_text I18n.t("admin.categories.title")
  end

  test "login page shows the store name for the subdomain" do
    visit_store stores(:cafe_delicias), login_path

    assert_text stores(:cafe_delicias).name
  end

  # The error text itself lives in an auto-dismissing toast, so asserting it in
  # the browser is racy. LoginFlashTest covers the message; these cover that the
  # attempt is actually refused.
  test "wrong password leaves the user on the login page" do
    visit_store stores(:cafe_delicias), login_path
    fill_in "employee_number", with: accounts(:waiter_juan_account).employee_number
    fill_in "password", with: "wrong-password"
    click_on I18n.t("login.submit")

    assert_current_path login_path
    assert_selector "input[name='employee_number']"
  end

  test "unknown employee number leaves the user on the login page" do
    visit_store stores(:cafe_delicias), login_path
    fill_in "employee_number", with: "NOPE-999"
    fill_in "password", with: PASSWORD
    click_on I18n.t("login.submit")

    assert_current_path login_path
    assert_selector "input[name='employee_number']"
  end

  test "signing out returns to the login page" do
    sign_in_waiter

    click_on I18n.t("exit")

    assert_current_path login_path
    assert_selector "input[name='employee_number']"
  end

  test "visiting a protected page while signed out redirects to login" do
    visit_store stores(:cafe_delicias), kitchen_path

    assert_current_path login_path
  end

  test "an unknown subdomain does not resolve to a store" do
    Capybara.app_host = "http://no-such-store.example.com:#{Capybara.current_session.server.port}"
    visit login_path

    assert_text I18n.t("flash.store_not_found")
  end
end
