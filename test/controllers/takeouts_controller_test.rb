require "test_helper"

class TakeoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "index shows takeout orders page" do
    get takeouts_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match I18n.t("takeouts.title"), response.body
  end

  test "index auto-creates takeout spot if missing" do
    Spot.where(store: @store, spot_type: :takeout).delete_all

    assert_difference "Spot.count", 1 do
      get takeouts_url(subdomain: @store.subdomain)
    end
    assert_response :success
  end

  test "creating order on takeout spot works" do
    spot = Spot.takeout_for(@store)
    assert_difference "Order.count", 1 do
      post spot_orders_url(spot, subdomain: @store.subdomain)
    end
    order = @store.orders.order(created_at: :desc).first
    assert_equal spot, order.spot
    assert order.spot.takeout?
  end

  test "requires authentication" do
    delete logout_url(subdomain: @store.subdomain)
    get takeouts_url(subdomain: @store.subdomain)
    assert_redirected_to login_url
  end
end
