require "test_helper"

class TablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "index shows active tables" do
    get tables_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match "Mesa 1", response.body
    assert_match "Mesa 5", response.body
  end

  test "index shows table with active order status" do
    get tables_url(subdomain: @store.subdomain)
    assert_response :success
    # Mesa 1 has a cooking order
    assert_match "Preparando", response.body
  end

  test "requires authentication" do
    delete logout_url(subdomain: @store.subdomain)
    get tables_url(subdomain: @store.subdomain)
    assert_redirected_to login_url
  end

  # The card carries one line of instruction: something is plated for this
  # table. The counts it used to print (how many are cooked, how many were
  # carried out) are on the order itself.
  test "index tells a table there is food waiting to be taken over" do
    line_items(:cooking_cappuccino).mark_ready!

    get tables_url(subdomain: @store.subdomain)

    assert_response :success
    assert_match I18n.t("tables.items_awaiting", count: 1), response.body
    assert_no_match(/entregados/, response.body)
  end

  test "index says nothing about delivery while the kitchen still has it all" do
    get tables_url(subdomain: @store.subdomain)

    assert_response :success
    assert_no_match(/listo para entregar/, response.body)
  end
end
