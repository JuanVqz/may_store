require "test_helper"

class Admin::ComponentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @other_store = stores(:mi_cafe)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
    @component = components(:espresso_shot)
  end

  test "index lists store components" do
    get admin_components_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match @component.name, response.body
  end

  test "index does not show other store components" do
    other = Component.create!(store: @other_store, name: "Other Ingredient", price_cents: 0, available: true)
    get admin_components_url(subdomain: @store.subdomain)
    assert_no_match other.name, response.body
  end

  test "new renders form" do
    get new_admin_component_url(subdomain: @store.subdomain)
    assert_response :success
  end

  test "create adds component to store" do
    assert_difference "Component.count", 1 do
      post admin_components_url(subdomain: @store.subdomain),
        params: { component: { name: "Crema", price: "0.00", available: "1" } }
    end
    assert_redirected_to admin_components_url(subdomain: @store.subdomain)
    assert_equal @store, Component.last.store
  end

  test "create with blank name re-renders form" do
    assert_no_difference "Component.count" do
      post admin_components_url(subdomain: @store.subdomain),
        params: { component: { name: "", price: "0" } }
    end
    assert_response :unprocessable_entity
  end

  test "update changes component" do
    patch admin_component_url(@component, subdomain: @store.subdomain),
      params: { component: { name: "Double Espresso", price: "5.00", available: "1" } }
    assert_redirected_to admin_components_url(subdomain: @store.subdomain)
    assert_equal "Double Espresso", @component.reload.name
    assert_equal 500, @component.reload.price_cents
  end

  test "destroy soft-deletes component" do
    delete admin_component_url(@component, subdomain: @store.subdomain)
    assert_redirected_to admin_components_url(subdomain: @store.subdomain)
    assert_predicate @component.reload, :deleted?
  end

  test "cannot access other store component" do
    other = Component.create!(store: @other_store, name: "Other", price_cents: 0, available: true)
    get edit_admin_component_url(other, subdomain: @store.subdomain)
    assert_response :not_found
  end
end
