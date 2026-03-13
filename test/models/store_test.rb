require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "validates presence of name" do
    store = Store.new(subdomain: "test", order_prefix: "TST")
    assert_not store.valid?
    assert store.errors[:name].any?
  end

  test "validates uniqueness of subdomain" do
    store = Store.new(name: "Duplicate", subdomain: stores(:cafe_delicias).subdomain, order_prefix: "DUP")
    assert_not store.valid?
  end

  test "validates uniqueness of order_prefix" do
    store = Store.new(name: "Duplicate", subdomain: "dup", order_prefix: stores(:cafe_delicias).order_prefix)
    assert_not store.valid?
  end

  test "normalizes subdomain to lowercase" do
    store = Store.new(subdomain: " CAFE ")
    assert_equal "cafe", store.subdomain
  end

  test "normalizes order_prefix to uppercase" do
    store = Store.new(order_prefix: " cfe ")
    assert_equal "CFE", store.order_prefix
  end

  test "validates order_prefix max length" do
    store = Store.new(name: "Test", subdomain: "test", order_prefix: "TOOLONG")
    assert_not store.valid?
  end
end
