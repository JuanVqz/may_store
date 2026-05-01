require "test_helper"

class Admin::PaymentMethodsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @other_store = stores(:mi_cafe)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
    @payment_method = payment_methods(:efectivo)
  end

  test "index lists store payment methods" do
    get admin_payment_methods_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match @payment_method.name, response.body
  end

  test "index does not show other store payment methods" do
    other = PaymentMethod.create!(store: @other_store, name: "Other Pay", active: true)
    get admin_payment_methods_url(subdomain: @store.subdomain)
    assert_no_match other.name, response.body
  end

  test "new renders form" do
    get new_admin_payment_method_url(subdomain: @store.subdomain)
    assert_response :success
  end

  test "create adds payment method to store" do
    assert_difference "PaymentMethod.count", 1 do
      post admin_payment_methods_url(subdomain: @store.subdomain),
        params: { payment_method: { name: "Débito", active: "1" } }
    end
    assert_redirected_to admin_payment_methods_url(subdomain: @store.subdomain)
    assert_equal @store, PaymentMethod.last.store
  end

  test "create with blank name re-renders form" do
    assert_no_difference "PaymentMethod.count" do
      post admin_payment_methods_url(subdomain: @store.subdomain),
        params: { payment_method: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "update changes payment method" do
    patch admin_payment_method_url(@payment_method, subdomain: @store.subdomain),
      params: { payment_method: { name: "Efectivo MXN", active: "1" } }
    assert_redirected_to admin_payment_methods_url(subdomain: @store.subdomain)
    assert_equal "Efectivo MXN", @payment_method.reload.name
  end

  test "destroy deletes payment method" do
    pm = PaymentMethod.create!(store: @store, name: "Temporal", active: true)
    delete admin_payment_method_url(pm, subdomain: @store.subdomain)
    assert_redirected_to admin_payment_methods_url(subdomain: @store.subdomain)
    assert_raises(ActiveRecord::RecordNotFound) { pm.reload }
  end

  test "unauthenticated request redirects to login" do
    delete logout_url(subdomain: @store.subdomain)
    get admin_payment_methods_url(subdomain: @store.subdomain)
    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "cannot access other store payment method" do
    other = PaymentMethod.create!(store: @other_store, name: "Other", active: true)
    get edit_admin_payment_method_url(other, subdomain: @store.subdomain)
    assert_response :not_found
  end
end
