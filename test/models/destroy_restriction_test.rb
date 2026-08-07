require "test_helper"

# Spots and payment methods are referenced by orders and payments with database
# foreign keys. Destroying one that is still referenced used to raise
# ActiveRecord::InvalidForeignKey and blow up as a 500 in the admin area, so the
# rule lives on the model as `dependent: :restrict_with_error`.
class DestroyRestrictionTest < ActiveSupport::TestCase
  test "a spot with orders cannot be destroyed" do
    spot = spots(:mesa_5)
    assert spot.orders.any?

    assert_no_difference "Spot.count" do
      assert_not spot.destroy
    end
    assert_includes spot.errors.full_messages,
      I18n.t("activerecord.errors.models.spot.attributes.base.restrict_dependent_destroy.has_many")
  end

  test "a spot without orders can be destroyed" do
    spot = spots(:mesa_2)
    assert_empty spot.orders

    assert_difference "Spot.count", -1 do
      assert spot.destroy
    end
  end

  test "a payment method with payments cannot be destroyed" do
    method = payment_methods(:efectivo)
    assert method.payments.any?

    assert_no_difference "PaymentMethod.count" do
      assert_not method.destroy
    end
    assert_includes method.errors.full_messages,
      I18n.t("activerecord.errors.models.payment_method.attributes.base.restrict_dependent_destroy.has_many")
  end

  test "a payment method without payments can be destroyed" do
    method = payment_methods(:transferencia)
    assert_empty method.payments

    assert_difference "PaymentMethod.count", -1 do
      assert method.destroy
    end
  end

  test "the restriction reports in Spanish rather than raising" do
    spot = spots(:mesa_5)

    assert_nothing_raised { spot.destroy }
    assert_no_match(/translation missing/i, spot.errors.full_messages.to_sentence)
    assert_match(/no se puede eliminar/i, spot.errors.full_messages.to_sentence)
  end
end
