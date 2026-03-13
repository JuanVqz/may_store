require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "validates presence of name and role" do
    user = User.new(store: stores(:cafe_delicias))
    assert_not user.valid?
    assert user.errors[:name].any?
    assert user.errors[:role].any?
  end

  test "role enum works" do
    user = users(:waiter_juan)
    assert user.waiter?
    assert_not user.kitchen?
  end

  test "soft delete" do
    user = users(:waiter_juan)
    assert_not user.deleted?

    user.soft_delete!
    assert user.deleted?
    assert_not_includes User.active, user
    assert_includes User.deleted, user

    user.restore!
    assert_not user.deleted?
    assert_includes User.active, user
  end

  test "normalizes email" do
    user = User.new(email: " JUAN@CAFE.COM ")
    assert_equal "juan@cafe.com", user.email
  end

  test "role_label returns i18n string" do
    user = users(:waiter_juan)
    assert_equal I18n.t("roles.waiter"), user.role_label
  end
end
