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

  test "a payment method used by a cash closing cannot be destroyed" do
    method = payment_methods(:mercado_pago)
    assert_empty method.payments, "fixture must isolate the cash closing line FK"
    assert method.cash_closing_lines.any?

    assert_no_difference "PaymentMethod.count" do
      assert_not method.destroy
    end
    assert_includes method.errors.full_messages,
      I18n.t("activerecord.errors.models.payment_method.attributes.base.restrict_dependent_destroy.has_many")
  end

  test "a payment method with no references at all can be destroyed" do
    method = payment_methods(:transferencia)
    assert_empty method.payments
    assert_empty method.cash_closing_lines

    assert_difference "PaymentMethod.count", -1 do
      assert method.destroy
    end
  end

  # The guard is per-association, so adding a new inbound foreign key silently
  # reintroduces the 500 these tests exist to prevent. This checks the schema
  # against the model rather than trusting anyone to remember.
  test "every foreign key pointing at payment methods is guarded" do
    assert_empty unguarded_foreign_keys_for(PaymentMethod)
  end

  test "every foreign key pointing at spots is guarded" do
    assert_empty unguarded_foreign_keys_for(Spot)
  end

  private
    def unguarded_foreign_keys_for(model)
      connection = ActiveRecord::Base.connection

      inbound = connection.tables.flat_map do |table|
        connection.foreign_keys(table)
          .select { |fk| fk.to_table == model.table_name }
          .map(&:from_table)
      end.uniq

      guarded = model.reflect_on_all_associations(:has_many)
        .select { |association| association.options[:dependent] == :restrict_with_error }
        .map { |association| association.klass.table_name }

      (inbound - guarded).tap do |missing|
        next if missing.empty?
        flunk "unguarded foreign keys to #{model.table_name}: #{missing.join(', ')}"
      end
    end

  test "the restriction reports in Spanish rather than raising" do
    spot = spots(:mesa_5)

    assert_nothing_raised { spot.destroy }
    assert_no_match(/translation missing/i, spot.errors.full_messages.to_sentence)
    assert_match(/no se puede eliminar/i, spot.errors.full_messages.to_sentence)
  end
end
