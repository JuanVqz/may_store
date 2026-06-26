require "test_helper"

class Admin::PaginationSmokeTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
  end

  test "renders pagy 43 series nav across multiple pages" do
    original = Pagy::OPTIONS[:limit]
    Pagy::OPTIONS[:limit] = 1
    get admin_products_url(subdomain: @store.subdomain, page: 2)
    assert_response :success
    # previous/next + numbered links rendered without raising on series/page_url
    assert_match I18n.t("admin.pagination.previous"), response.body
    assert_match I18n.t("admin.pagination.next"), response.body
    assert_match "page=1", response.body
    assert_match "page=3", response.body
  ensure
    Pagy::OPTIONS[:limit] = original
  end
end
