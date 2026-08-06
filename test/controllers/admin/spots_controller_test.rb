require "test_helper"

class Admin::SpotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @other_store = stores(:mi_cafe)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
    @spot = spots(:mesa_1)
  end

  test "index lists store spots" do
    get admin_spots_url(subdomain: @store.subdomain)
    assert_response :success
    assert_match @spot.name, response.body
  end

  test "index does not show other store spots" do
    other = Spot.create!(store: @other_store, name: "Mesa X", spot_type: :dine_in)
    get admin_spots_url(subdomain: @store.subdomain)
    assert_no_match other.name, response.body
  end

  test "new renders form" do
    get new_admin_spot_url(subdomain: @store.subdomain)
    assert_response :success
  end

  test "create adds spot to store" do
    assert_difference "Spot.count", 1 do
      post admin_spots_url(subdomain: @store.subdomain),
        params: { spot: { name: "Mesa 10", spot_type: "dine_in", active: "1" } }
    end
    assert_redirected_to admin_spots_url(subdomain: @store.subdomain)
    assert_equal @store, Spot.last.store
  end

  test "create with blank name re-renders form" do
    assert_no_difference "Spot.count" do
      post admin_spots_url(subdomain: @store.subdomain),
        params: { spot: { name: "", spot_type: "dine_in" } }
    end
    assert_response :unprocessable_entity
  end

  test "update changes spot" do
    patch admin_spot_url(@spot, subdomain: @store.subdomain),
      params: { spot: { name: "Mesa Uno", spot_type: "dine_in", active: "1" } }
    assert_redirected_to admin_spots_url(subdomain: @store.subdomain)
    assert_equal "Mesa Uno", @spot.reload.name
  end

  test "destroy deletes spot" do
    spot = Spot.create!(store: @store, name: "Temp Mesa", spot_type: :dine_in)
    delete admin_spot_url(spot, subdomain: @store.subdomain)
    assert_redirected_to admin_spots_url(subdomain: @store.subdomain)
    assert_raises(ActiveRecord::RecordNotFound) { spot.reload }
  end

  test "unauthenticated request redirects to login" do
    delete logout_url(subdomain: @store.subdomain)
    get admin_spots_url(subdomain: @store.subdomain)
    assert_redirected_to login_url(subdomain: @store.subdomain)
  end

  test "cannot access other store spot" do
    other = Spot.create!(store: @other_store, name: "Mesa Y", spot_type: :dine_in)
    get edit_admin_spot_url(other, subdomain: @store.subdomain)
    assert_response :not_found
  end
end
