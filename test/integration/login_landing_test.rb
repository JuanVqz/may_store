require "test_helper"

# A role is a default screen, not a set of permissions. Signing in should drop
# each employee where their shift starts; nothing here is a restriction.
class LoginLandingTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
  end

  test "the kitchen lands on the queue" do
    sign_in "KIT-001"

    assert_redirected_to kitchen_url(subdomain: @store.subdomain)
  end

  test "a waiter lands on the floor" do
    sign_in "EMP-001"

    assert_redirected_to root_url(subdomain: @store.subdomain)
  end

  test "an admin lands on the floor too" do
    sign_in "ADM-001"

    assert_redirected_to root_url(subdomain: @store.subdomain)
  end

  # Landing somewhere is not permission to stay there: every screen is open to
  # every role.
  test "the kitchen can still reach the floor and an admin the queue" do
    sign_in "KIT-001"
    get root_url(subdomain: @store.subdomain)
    assert_response :success

    sign_in "ADM-001"
    get kitchen_url(subdomain: @store.subdomain)
    assert_response :success
  end

  private

  def sign_in(employee_number)
    post login_url(subdomain: @store.subdomain),
         params: { employee_number: employee_number, password: "password123" }
  end
end
