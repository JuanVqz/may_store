require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "index shows home page with tables and takeout links" do
    get root_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match I18n.t("home.tables"), response.body
    assert_match I18n.t("home.takeout"), response.body
  end

  test "requires authentication" do
    delete logout_url(subdomain: @store.subdomain)
    get root_url(subdomain: @store.subdomain)
    assert_redirected_to login_url
  end
end
