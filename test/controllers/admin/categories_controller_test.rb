require "test_helper"

class Admin::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @other_store = stores(:mi_cafe)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
    @category = categories(:bebidas_calientes)
  end

  test "index lists store categories" do
    get admin_categories_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match @category.name, response.body
  end

  test "index does not show other store categories" do
    other = Category.create!(store: @other_store, name: "Other Cat", position: 1)
    get admin_categories_url(subdomain: @store.subdomain)
    assert_no_match other.name, response.body
  end

  test "new renders form" do
    get new_admin_category_url(subdomain: @store.subdomain)
    assert_response :success
  end

  test "create adds category to store" do
    assert_difference "Category.count", 1 do
      post admin_categories_url(subdomain: @store.subdomain),
        params: { category: { name: "Nueva Categoria" } }
    end
    assert_redirected_to admin_categories_url(subdomain: @store.subdomain)
    assert_equal @store, Category.last.store
  end

  test "create with blank name re-renders form" do
    assert_no_difference "Category.count" do
      post admin_categories_url(subdomain: @store.subdomain),
        params: { category: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    get edit_admin_category_url(@category, subdomain: @store.subdomain)
    assert_response :success
  end

  test "update changes category name" do
    patch admin_category_url(@category, subdomain: @store.subdomain),
      params: { category: { name: "Bebidas Frias" } }
    assert_redirected_to admin_categories_url(subdomain: @store.subdomain)
    assert_equal "Bebidas Frias", @category.reload.name
  end

  test "destroy soft-deletes category" do
    delete admin_category_url(@category, subdomain: @store.subdomain)
    assert_redirected_to admin_categories_url(subdomain: @store.subdomain)
    assert_predicate @category.reload, :deleted?
  end

  test "unauthenticated request redirects to login" do
    delete logout_url(subdomain: @store.subdomain)
    get admin_categories_url(subdomain: @store.subdomain)
    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "cannot access other store category" do
    other = Category.create!(store: @other_store, name: "Other", position: 1)
    get edit_admin_category_url(other, subdomain: @store.subdomain)
    assert_response :not_found
  end
end
