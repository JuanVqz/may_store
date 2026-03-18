require "test_helper"

class PaymentMethodTest < ActiveSupport::TestCase
  test "active scope returns only active methods" do
    method = payment_methods(:efectivo)
    assert_includes PaymentMethod.active, method

    method.update!(active: false)
    assert_not_includes PaymentMethod.active, method
  end
end
