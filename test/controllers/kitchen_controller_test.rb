require "test_helper"

class KitchenControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "index shows cooking and ready line items" do
    get kitchen_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match line_items(:cooking_cappuccino).product.name.upcase, response.body
    assert_match line_items(:cooking_americano).product.name.upcase, response.body
  end

  test "index excludes delivered and cancelled items" do
    line_items(:cooking_cappuccino).mark_ready!
    line_items(:cooking_cappuccino).mark_delivered!
    line_items(:cooking_americano).cancel!

    get kitchen_url(subdomain: @store.subdomain)
    assert_response :success
    assert_no_match(/#{line_items(:cooking_cappuccino).product.name.upcase}/, response.body)
    assert_no_match(/#{line_items(:cooking_americano).product.name.upcase}/, response.body)
  end

  test "index orders by oldest first" do
    get kitchen_url(subdomain: @store.subdomain)
    assert_response :success
    assert_select "#kitchen-queue"
  end

  test "index requires authentication" do
    delete logout_url(subdomain: @store.subdomain)
    get kitchen_url(subdomain: @store.subdomain)
    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "index shows queue count" do
    get kitchen_url(subdomain: @store.subdomain)
    assert_select "#kitchen-queue-count", /2/
  end
end
