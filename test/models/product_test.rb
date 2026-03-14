require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "available scope filters by available flag" do
    product = products(:americano)
    assert_includes Product.available, product

    product.update!(available: false)
    assert_not_includes Product.available, product
  end

  test "soft delete and restore" do
    product = products(:americano)
    product.soft_delete!
    assert product.deleted?
    assert_not_includes Product.active, product

    product.restore!
    assert_not product.deleted?
    assert_includes Product.active, product
  end

  test "price helpers from PriceCents" do
    product = products(:americano)
    assert_equal product.base_price_cents / 100.0, product.base_price
    assert product.formatted_base_price.start_with?("$")
  end

  test "belongs to store and category" do
    product = products(:americano)
    assert_not_nil product.store
    assert_not_nil product.category
  end
end
