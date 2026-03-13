require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "authenticates with correct password" do
    account = accounts(:waiter_juan_account)
    assert account.authenticate("password123")
    assert_not account.authenticate("wrong")
  end

  test "validates employee_number presence" do
    account = Account.new(user: users(:waiter_juan), password: "test123")
    account.employee_number = nil
    assert_not account.valid?
  end

  test "normalizes employee_number to uppercase" do
    account = Account.new(employee_number: " emp-099 ")
    assert_equal "EMP-099", account.employee_number
  end

  test "employee_number unique per store" do
    # EMP-001 exists for cafe_delicias (waiter_juan)
    new_user = User.create!(store: stores(:cafe_delicias), name: "New User", role: :waiter)
    account = Account.new(user: new_user, employee_number: "EMP-001", password: "test123")
    assert_not account.valid?
    assert account.errors[:employee_number].any?
  end

  test "same employee_number allowed in different stores" do
    # EMP-001 exists in both stores via fixtures - this is valid
    account = accounts(:other_store_account)
    assert account.valid?
  end
end
