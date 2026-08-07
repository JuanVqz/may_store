require "application_system_test_case"

class AdminCatalogTest < ApplicationSystemTestCase
  setup do
    sign_in_admin
  end

  # ---------------------------------------------------------------- categories

  test "creating a category" do
    visit admin_categories_path
    click_on I18n.t("admin.categories.new")

    fill_in "category_name", with: "Postres"
    click_on I18n.t("save")

    assert_text "Postres"
    assert Category.active.exists?(name: "Postres")
  end

  test "a category name is required" do
    visit new_admin_category_path

    assert_no_difference "Category.count" do
      click_on I18n.t("save")
      assert_text I18n.t("activerecord.errors.messages.blank")
    end

    assert_current_path new_admin_category_path
    assert_no_text I18n.t("admin.categories.created")
  end

  test "editing a category" do
    visit admin_categories_path

    within_row categories(:bebidas_calientes).name do
      click_on I18n.t("edit")
    end
    fill_in "category_name", with: "Bebidas Frias"
    click_on I18n.t("save")

    assert_text "Bebidas Frias"
  end

  test "deleting a category soft deletes it" do
    category = categories(:crepas)
    visit admin_categories_path

    within_row category.name do
      accept_confirm { click_on I18n.t("delete") }
    end

    assert_no_text category.name
    assert_not_nil category.reload.deleted_at
  end

  test "searching categories by name" do
    visit admin_categories_path

    fill_in "q", with: "Crepas"
    click_on I18n.t("admin.search")

    assert_text categories(:crepas).name
    assert_no_text categories(:bebidas_calientes).name
  end

  # ---------------------------------------------------------------- components

  test "creating an ingredient" do
    visit admin_components_path
    click_on I18n.t("admin.components.new")

    fill_in "component_name", with: "Canela"
    fill_in "component_price", with: "5"
    click_on I18n.t("save")

    assert_text "Canela"
    assert Component.active.exists?(name: "Canela")
  end

  test "editing an ingredient price" do
    visit admin_components_path

    within_row components(:extra_chocolate).name do
      click_on I18n.t("edit")
    end
    fill_in "component_price", with: "15"
    click_on I18n.t("save")

    assert_current_path admin_components_path
    assert_equal 1500, components(:extra_chocolate).reload.price_cents
  end

  test "deleting an ingredient soft deletes it" do
    component = components(:extra_strawberries)
    visit admin_components_path

    within_row component.name do
      accept_confirm { click_on I18n.t("delete") }
    end

    assert_no_text component.name
    assert_not_nil component.reload.deleted_at
  end

  # ------------------------------------------------------------------ products

  test "creating a product" do
    visit admin_products_path
    click_on I18n.t("admin.products.new")

    fill_in "product_name", with: "Chai Latte"
    fill_in "product_base_price", with: "55"
    select categories(:bebidas_calientes).name, from: "product_category_id"
    click_on I18n.t("save")

    assert_text "Chai Latte"
    assert_equal 5500, Product.find_by(name: "Chai Latte").base_price_cents
  end

  test "editing a product price" do
    visit admin_products_path

    within_row products(:americano).name do
      click_on I18n.t("edit")
    end
    fill_in "product_base_price", with: "40"
    click_on I18n.t("save")

    assert_current_path admin_products_path
    assert_equal 4000, products(:americano).reload.base_price_cents
  end

  test "deleting a product soft deletes it and removes it from the order browser" do
    product = products(:latte)
    visit admin_products_path

    within_row product.name do
      accept_confirm { click_on I18n.t("delete") }
    end

    assert_no_text product.name
    assert_not_nil product.reload.deleted_at

    visit order_path(orders(:open_order))
    within "#product_browser" do
      assert_no_text product.name
    end
  end

  test "an unavailable product is hidden from the order browser but kept in admin" do
    product = products(:latte)
    product.update!(available: false)

    visit admin_products_path
    assert_text product.name

    visit order_path(orders(:open_order))
    within "#product_browser" do
      assert_no_text product.name
    end
  end

  # --------------------------------------------------------------------- spots

  test "creating a spot" do
    visit admin_spots_path
    click_on I18n.t("admin.spots.new")

    fill_in "spot_name", with: "Mesa 99"
    select I18n.t("spot_types.dine_in"), from: "spot_spot_type"
    click_on I18n.t("save")

    assert_text "Mesa 99"
  end

  test "a new spot shows up on the tables screen" do
    visit admin_spots_path
    click_on I18n.t("admin.spots.new")
    fill_in "spot_name", with: "Mesa 42"
    select I18n.t("spot_types.dine_in"), from: "spot_spot_type"
    click_on I18n.t("save")

    visit tables_path

    assert_text "Mesa 42"
  end

  test "deleting an unused spot removes it" do
    spot = spots(:mesa_2)
    visit admin_spots_path

    within_row spot.name do
      accept_confirm { click_on I18n.t("delete") }
    end

    assert_no_text spot.name
    assert_nil Spot.find_by(id: spot.id)
  end

  test "a spot with orders cannot be deleted and says so instead of erroring" do
    spot = spots(:mesa_5)
    assert spot.orders.any?

    visit admin_spots_path
    within_row spot.name do
      accept_confirm { click_on I18n.t("delete") }
    end

    # The message wording is asserted in test/models/destroy_restriction_test.rb.
    # Here the durable fact is that the row survived rather than 500ing.
    assert_text spot.name
    assert_not_nil Spot.find_by(id: spot.id)
  end

  # ----------------------------------------------------------- payment methods

  test "creating a payment method" do
    visit admin_payment_methods_path
    click_on I18n.t("admin.payment_methods.new")

    fill_in "payment_method_name", with: "Vales"
    click_on I18n.t("save")

    assert_text "Vales"
  end

  test "a new payment method is offered on the bill" do
    visit admin_payment_methods_path
    click_on I18n.t("admin.payment_methods.new")
    fill_in "payment_method_name", with: "Vales"
    click_on I18n.t("save")

    order = orders(:delivered_order)
    order.payments.destroy_all
    order.update!(total_cents: 4500)

    visit bill_order_path(order)

    assert_text "Vales"
  end

  test "a payment method with payments cannot be deleted and says so instead of erroring" do
    method = payment_methods(:efectivo)
    assert method.payments.any?

    visit admin_payment_methods_path
    within_row method.name do
      accept_confirm { click_on I18n.t("delete") }
    end

    assert_text method.name
    assert_not_nil PaymentMethod.find_by(id: method.id)
  end

  test "deleting an unused payment method removes it" do
    method = payment_methods(:transferencia)
    assert_empty method.payments

    visit admin_payment_methods_path
    within_row method.name do
      accept_confirm { click_on I18n.t("delete") }
    end

    assert_no_text method.name
    assert_nil PaymentMethod.find_by(id: method.id)
  end

  # ------------------------------------------------------------------ navigation

  test "the admin nav reaches every catalog screen" do
    visit admin_root_path

    click_on I18n.t("admin.nav.components")
    assert_current_path admin_components_path

    click_on I18n.t("admin.nav.products")
    assert_current_path admin_products_path

    click_on I18n.t("admin.nav.spots")
    assert_current_path admin_spots_path

    click_on I18n.t("admin.nav.payment_methods")
    assert_current_path admin_payment_methods_path

    click_on I18n.t("admin.nav.categories")
    assert_current_path admin_categories_path
  end

  private
    def within_row(text, &block)
      within(:xpath, "//tr[.//*[normalize-space(text())='#{text}']]", &block)
    end
end
