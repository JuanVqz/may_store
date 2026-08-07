require "application_system_test_case"

class OrderFlowTest < ApplicationSystemTestCase
  setup do
    sign_in_waiter
  end

  test "opening an order from a free table" do
    visit tables_path

    assert_difference "Order.count", 1 do
      click_on spots(:mesa_2).name
      assert_text I18n.t("order.no_items")
    end

    assert_text spots(:mesa_2).name
    assert_text I18n.t("order.no_items")
    assert_text products(:americano).name
  end

  test "a table with an active order links to that order instead of opening a new one" do
    visit tables_path

    assert_no_difference "Order.count" do
      click_on spots(:mesa_5).name
      assert_text orders(:open_order).code
    end
  end

  test "adding a product without customization" do
    visit order_path(orders(:open_order))

    within "#product_browser" do
      click_on I18n.t("products.add_to_order"), match: :first
    end

    within "#order_items" do
      assert_text products(:americano).name
    end
  end

  test "the order total reflects the items added" do
    order = orders(:open_order)
    visit order_path(order)

    assert_text "$35.00"

    within "#product_browser" do
      click_on I18n.t("products.add_to_order"), match: :first
    end

    # The fixture order already holds one americano at $35.00.
    within "#order_summary" do
      assert_text "$70.00"
    end
  end

  test "customizing a product with a reduced ingredient portion" do
    visit order_path(orders(:open_order))

    open_customization_for products(:cappuccino)

    within customization_selector(products(:cappuccino)) do
      within(*portion_group_for(components(:steamed_milk))) do
        choose_portion I18n.t("portions.half")
      end
      click_on I18n.t("products.add_to_order")
    end

    within "#order_items" do
      assert_text products(:cappuccino).name
      assert_text "#{components(:steamed_milk).name}: #{I18n.t('portions.half')}"
    end
  end

  test "a required ingredient cannot be removed entirely" do
    visit order_path(orders(:open_order))

    open_customization_for products(:cappuccino)

    within customization_selector(products(:cappuccino)) do
      # Espresso Shot is required, so it offers no "Sin" option.
      within(*portion_group_for(components(:espresso_shot))) do
        assert_no_text I18n.t("portions.none")
      end
      # Steamed Milk is optional, so it does.
      within(*portion_group_for(components(:steamed_milk))) do
        assert_text I18n.t("portions.none")
      end
    end
  end

  test "adding the same extra twice records a quantity of two" do
    visit order_path(orders(:open_order))

    open_customization_for products(:cappuccino)

    within customization_selector(products(:cappuccino)) do
      within(*extra_row_for(components(:extra_chocolate))) do
        click_on "+"
        click_on "+"
      end
      click_on I18n.t("products.add_to_order")
    end

    within "#order_items" do
      assert_text "#{components(:extra_chocolate).name} x2"
    end
  end

  test "extras add their price to the line total" do
    visit order_path(orders(:open_order))

    open_customization_for products(:cappuccino)

    within customization_selector(products(:cappuccino)) do
      within(*extra_row_for(components(:extra_chocolate))) do
        click_on "+"
      end
      click_on I18n.t("products.add_to_order")
    end

    # Cappuccino $45.00 + Extra Chocolate $10.00
    within "#order_items" do
      assert_text "$55.00"
    end
  end

  test "special notes are attached to the line item" do
    visit order_path(orders(:open_order))

    open_customization_for products(:cappuccino)

    within customization_selector(products(:cappuccino)) do
      fill_in "special_notes", with: "Sin azucar por favor"
      click_on I18n.t("products.add_to_order")
    end

    within "#order_items" do
      assert_text "Sin azucar por favor"
    end
  end

  test "removing an item from an open order" do
    visit order_path(orders(:open_order))

    within "#line_item_#{line_items(:ordering_americano).id}" do
      click_on I18n.t("delete")
    end

    assert_text I18n.t("order.no_items")
  end

  test "switching product categories filters the browser" do
    visit order_path(orders(:open_order))

    assert_text products(:americano).name

    within "#product_browser" do
      click_on categories(:crepas).name
    end

    # The crepas category has no products in the fixtures. Scope the check to
    # the browser, since the order itself still lists an americano.
    within "#product_browser" do
      assert_text I18n.t("no_results")
      assert_no_text products(:americano).name
    end
  end

  test "confirming an order sends every item to the kitchen" do
    order = orders(:open_order)
    visit order_path(order)

    click_on I18n.t("order.confirm")

    # The status badge is durable page state; the flash toast is not.
    within "#order_header" do
      assert_text I18n.t("order_statuses.cooking")
    end
    assert_equal "cooking", order.reload.status
    assert_equal [ "cooking" ], order.line_items.pluck(:status).uniq
  end

  test "an order with no items cannot be confirmed" do
    order = orders(:open_order)
    order.line_items.destroy_all
    visit order_path(order)

    assert_text I18n.t("order.no_items")
    assert_no_button I18n.t("order.confirm")
  end

  test "items added after confirmation go straight to cooking" do
    order = orders(:cooking_order)
    visit order_path(order)

    within "#product_browser" do
      click_on I18n.t("products.add_to_order"), match: :first
    end

    within "#order_items" do
      assert_text products(:americano).name
    end
    assert_equal "cooking", order.line_items.order(:created_at).last.status
  end

  test "cancelling an order returns the table to available" do
    order = orders(:open_order)
    visit order_path(order)

    accept_confirm do
      click_on I18n.t("order.cancel_order")
    end

    assert_current_path tables_path
    within "#spot_#{order.spot_id}" do
      assert_text I18n.t("tables.available")
    end
    assert_equal "cancelled", order.reload.status
  end

  test "a closed order shows the closed view instead of the product browser" do
    order = orders(:delivered_order)
    order.update!(status: :closed, closed_at: Time.current)

    visit order_path(order)

    assert_text I18n.t("order.closed_title")
    assert_no_selector "#product_browser"
  end

  private
    # The customize button carries the product id, which is the most stable
    # hook the markup offers.
    def open_customization_for(product)
      find("button[data-product-id='#{product.id}']").click
      assert_selector customization_selector(product)
    end

    def customization_selector(product)
      "#customization_product_#{product.id}"
    end

    # Each ingredient renders a <div><strong>Name</strong></div> followed by the
    # portion button group.
    def portion_group_for(component)
      [ :xpath, ".//div[strong[normalize-space(text())='#{component.name}']]/following-sibling::div[@data-portion-group][1]" ]
    end

    def extra_row_for(component)
      [ :xpath, ".//div[@data-extra-row][.//strong[normalize-space(text())='#{component.name}']]" ]
    end

    def choose_portion(label)
      find("label", text: label, exact_text: true).click
    end
end
