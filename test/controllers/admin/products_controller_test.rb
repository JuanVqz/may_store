require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @other_store = stores(:mi_cafe)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
    @product = products(:americano)
    @category = categories(:bebidas_calientes)
  end

  test "index lists store products" do
    get admin_products_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match @product.name, response.body
  end

  test "index does not show other store products" do
    other_cat = Category.create!(store: @other_store, name: "Cat", position: 1)
    other = Product.create!(store: @other_store, category: other_cat, name: "Other Product", base_price_cents: 1000, available: true)
    get admin_products_url(subdomain: @store.subdomain)
    assert_no_match other.name, response.body
  end

  test "new renders form" do
    get new_admin_product_url(subdomain: @store.subdomain)
    assert_response :success
  end

  test "create adds product to store" do
    assert_difference "Product.count", 1 do
      post admin_products_url(subdomain: @store.subdomain),
        params: { product: { name: "Mocha", base_price: "45.00", category_id: @category.id, available: "1" } }
    end
    assert_redirected_to admin_products_url(subdomain: @store.subdomain)
    assert_equal @store, Product.last.store
    assert_equal 4500, Product.last.base_price_cents
  end

  test "create with blank name re-renders form" do
    assert_no_difference "Product.count" do
      post admin_products_url(subdomain: @store.subdomain),
        params: { product: { name: "", base_price: "10", category_id: @category.id } }
    end
    assert_response :unprocessable_entity
  end

  test "update changes product" do
    patch admin_product_url(@product, subdomain: @store.subdomain),
      params: { product: { name: "Americano Grande", base_price: "40.00", category_id: @category.id, available: "1" } }
    assert_redirected_to admin_products_url(subdomain: @store.subdomain)
    assert_equal "Americano Grande", @product.reload.name
    assert_equal 4000, @product.reload.base_price_cents
  end

  test "destroy soft-deletes product" do
    delete admin_product_url(@product, subdomain: @store.subdomain)
    assert_redirected_to admin_products_url(subdomain: @store.subdomain)
    assert_predicate @product.reload, :deleted?
  end

  test "cannot access other store product" do
    other_cat = Category.create!(store: @other_store, name: "Cat", position: 1)
    other = Product.create!(store: @other_store, category: other_cat, name: "Other", base_price_cents: 1000, available: true)
    get edit_admin_product_url(other, subdomain: @store.subdomain)
    assert_response :not_found
  end

  test "unauthenticated request redirects to login" do
    delete logout_url(subdomain: @store.subdomain)
    get admin_products_url(subdomain: @store.subdomain)
    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "create with nested product components saves them" do
    component = components(:espresso_shot)
    assert_difference "ProductComponent.count", 1 do
      post admin_products_url(subdomain: @store.subdomain),
        params: { product: {
          name: "Latte", base_price: "50.00", category_id: @category.id, available: "1",
          product_components_attributes: { "0" => { component_id: component.id, component_type: "ingredient" } }
        } }
    end
    assert_equal component, Product.last.product_components.first.component
  end

  test "create with empty nested component row does not create component" do
    assert_difference "ProductComponent.count", 0 do
      post admin_products_url(subdomain: @store.subdomain),
        params: { product: {
          name: "Plain", base_price: "30.00", category_id: @category.id, available: "1",
          product_components_attributes: { "0" => { component_id: "", component_type: "ingredient" } }
        } }
    end
    assert_response :redirect
  end
end
