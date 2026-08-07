require "application_system_test_case"

class MultitenancyTest < ApplicationSystemTestCase
  setup do
    @cafe = stores(:cafe_delicias)
    @other = stores(:mi_cafe)
  end

  test "the same employee number signs in to a different store" do
    # Both stores issue EMP-001, so the subdomain decides who you are.
    assert_equal accounts(:waiter_juan_account).employee_number,
      accounts(:other_store_account).employee_number

    sign_in_as accounts(:other_store_account).employee_number, store: @other

    assert_text @other.name
    assert_text users(:other_store_waiter).name
    assert_no_text users(:waiter_juan).name
  end

  test "signing in to one store does not carry over to another" do
    sign_in_waiter store: @cafe

    visit_store @other, tables_path

    assert_current_path login_path
  end

  test "a store only shows its own spots" do
    other_spot = Spot.create!(store: @other, name: "Barra Uno", spot_type: :dine_in, position: 1, active: true)
    sign_in_waiter store: @cafe

    visit tables_path

    assert_text spots(:mesa_1).name
    assert_no_text other_spot.name
  end

  test "a store only shows its own products" do
    other_category = Category.create!(store: @other, name: "Otra Categoria", position: 1, active: true)
    other_product = Product.create!(store: @other, category: other_category, name: "Producto Ajeno",
                                    base_price_cents: 1000, available: true)
    sign_in_waiter store: @cafe

    visit order_path(orders(:open_order))

    within "#product_browser" do
      assert_text products(:americano).name
      assert_no_text other_product.name
    end
  end

  test "an order from another store is not reachable by url" do
    other_spot = Spot.create!(store: @other, name: "Barra Dos", spot_type: :dine_in, position: 2, active: true)
    other_order = Order.create!(store: @other, spot: other_spot, user: users(:other_store_waiter),
                                status: :open, opened_at: Time.current)

    sign_in_waiter store: @cafe
    visit order_path(other_order)

    assert_no_text other_order.code
  end

  test "the kitchen queue only shows the current store's items" do
    other_spot = Spot.create!(store: @other, name: "Barra Tres", spot_type: :dine_in, position: 3, active: true)
    other_order = Order.create!(store: @other, spot: other_spot, user: users(:other_store_waiter),
                                status: :cooking, opened_at: Time.current)
    other_category = Category.create!(store: @other, name: "Cat Ajena", position: 1, active: true)
    other_product = Product.create!(store: @other, category: other_category, name: "Plato Ajeno",
                                    base_price_cents: 1000, available: true)
    LineItem.create!(order: other_order, product: other_product, status: :cooking,
                     base_price_cents: 1000, total_price_cents: 1000)

    sign_in_kitchen store: @cafe
    visit kitchen_path

    assert_text orders(:cooking_order).code
    assert_no_text other_order.code
  end

  test "the admin catalog only lists the current store's records" do
    other_category = Category.create!(store: @other, name: "Categoria Ajena", position: 1, active: true)

    sign_in_admin store: @cafe
    visit admin_categories_path

    assert_text categories(:bebidas_calientes).name
    assert_no_text other_category.name
  end

  test "each store keeps its own order code prefix" do
    assert_equal "CFE", @cafe.order_prefix
    assert_equal "MIA", @other.order_prefix

    sign_in_waiter store: @cafe
    visit tables_path
    click_on spots(:mesa_2).name

    assert_text(/#{@cafe.order_prefix}\d{4}-\d{3}/)
  end
end
