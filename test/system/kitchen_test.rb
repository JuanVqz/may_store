require "application_system_test_case"

class KitchenTest < ApplicationSystemTestCase
  setup do
    sign_in_kitchen
  end

  test "the queue lists cooking items grouped by order" do
    visit kitchen_path

    within "#kitchen-queue" do
      assert_text orders(:cooking_order).code
      assert_text products(:cappuccino).name.upcase
      assert_text products(:americano).name.upcase
    end
    assert_text I18n.t("kitchen.queue_count", count: 2)
  end

  test "the queue excludes items that are not cooking or ready" do
    visit kitchen_path

    # ordering_americano belongs to an unconfirmed order.
    within "#kitchen-queue" do
      assert_no_text orders(:open_order).code
    end
  end

  test "the queue shows an empty state when nothing is cooking" do
    LineItem.update_all(status: :delivered)

    visit kitchen_path

    assert_text I18n.t("kitchen.no_items")
    assert_text I18n.t("kitchen.queue_count", count: 0)
  end

  test "marking an item ready moves it out of the cooking state" do
    item = line_items(:cooking_cappuccino)
    visit kitchen_path

    within "#line_item_card_#{item.id}" do
      click_on I18n.t("kitchen.ready")
    end

    # Wait on a durable post-condition rather than the auto-dismissing toast.
    within "#line_item_card_#{item.id}" do
      assert_text I18n.t("kitchen.waiting_for_waiter")
    end
    assert_equal "ready", item.reload.status
  end

  test "an order becomes ready once every item is ready" do
    order = orders(:cooking_order)
    visit kitchen_path

    order.line_items.each do |item|
      within "#line_item_card_#{item.id}" do
        click_on I18n.t("kitchen.ready")
        assert_text I18n.t("kitchen.waiting_for_waiter")
      end
    end

    assert_equal "ready", order.reload.status
  end

  test "cancelling an item asks for confirmation first" do
    item = line_items(:cooking_americano)
    visit kitchen_path

    within "#line_item_card_#{item.id}" do
      dismiss_confirm { click_on I18n.t("kitchen.cancel") }
    end

    assert_equal "cooking", item.reload.status
  end

  test "confirming the dialog cancels the item" do
    item = line_items(:cooking_americano)
    visit kitchen_path

    within "#line_item_card_#{item.id}" do
      accept_confirm { click_on I18n.t("kitchen.cancel") }
    end

    # A cancelled item drops out of the queue entirely.
    assert_no_selector "#line_item_card_#{item.id}"
    assert_equal "cancelled", item.reload.status
  end

  test "a ready item can be delivered from the queue" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!(by: users(:kitchen_carlos))
    visit kitchen_path

    within "#line_item_card_#{item.id}" do
      click_on I18n.t("line_item.mark_delivered")
    end

    assert_no_selector "#line_item_card_#{item.id}"
    assert_equal "delivered", item.reload.status
  end

  test "a delivered item leaves the queue" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!(by: users(:kitchen_carlos))
    item.mark_delivered!(by: users(:kitchen_carlos))

    visit kitchen_path

    within "#kitchen-queue" do
      assert_no_selector "#line_item_card_#{item.id}"
    end
  end

  test "portion changes and notes reach the kitchen card" do
    item = line_items(:cooking_cappuccino)
    item.update!(special_notes: "Bien caliente")
    LineItemComponent.create!(
      line_item: item,
      component: components(:steamed_milk),
      component_type: :ingredient,
      portion: 0.5,
      unit_price_cents: 0
    )

    visit kitchen_path

    within "#line_item_card_#{item.id}" do
      assert_text "Bien caliente"
      assert_text components(:steamed_milk).name
    end
  end

  test "extras show a quantity on the kitchen card" do
    item = line_items(:cooking_cappuccino)
    2.times do
      LineItemComponent.create!(
        line_item: item,
        component: components(:extra_chocolate),
        component_type: :extra,
        portion: 1.0,
        unit_price_cents: components(:extra_chocolate).price_cents
      )
    end

    visit kitchen_path

    within "#line_item_card_#{item.id}" do
      assert_text "#{components(:extra_chocolate).name} x2"
    end
  end

  test "a takeout order is labelled as takeout in the queue" do
    order = Order.create!(
      store: stores(:cafe_delicias),
      spot: spots(:para_llevar),
      user: users(:waiter_juan),
      status: :cooking,
      opened_at: Time.current
    )
    LineItem.create!(order: order, product: products(:latte), status: :cooking,
                     base_price_cents: 4500, total_price_cents: 4500)

    visit kitchen_path

    within "[data-kitchen-order='#{order.id}']" do
      assert_text I18n.t("spot_types.takeout")
    end
  end

  test "an order splits its items into kitchen and bar columns" do
    order = orders(:cooking_order)
    crepa = LineItem.create!(order: order, product: products(:crepa_nutella), status: :cooking,
                             base_price_cents: 8500, total_price_cents: 8500)

    visit kitchen_path

    within "[data-kitchen-order='#{order.id}'] [data-kitchen-station='kitchen']" do
      assert_text products(:crepa_nutella).name.upcase
      assert_no_text products(:cappuccino).name.upcase
    end
    within "[data-kitchen-order='#{order.id}'] [data-kitchen-station='bar']" do
      assert_text products(:cappuccino).name.upcase
      assert_no_text crepa.product.name.upcase
    end
  end

  test "an order with a single station renders only that column" do
    order = orders(:cooking_order)

    visit kitchen_path

    within "[data-kitchen-order='#{order.id}']" do
      assert_selector "[data-kitchen-station='bar']"
      assert_no_selector "[data-kitchen-station='kitchen']"
    end
  end

  test "the order header shows a wait time that ticks on its own" do
    order = orders(:cooking_order)
    # The label counts from the newest of cooking_at and the oldest item, both of
    # which are fixture timestamps: by the time the system tests run, the fixtures
    # are over a minute old and the assertion below reads 1, not 0. Pin them to
    # now so the test measures the label, not how long the suite took to get here.
    order.update_columns(cooking_at: Time.current)
    order.line_items.update_all(created_at: Time.current)

    visit kitchen_path

    within "[data-kitchen-order='#{order.id}']" do
      assert_text I18n.t("kitchen.waiting", minutes: 0)
      # The Stimulus controller owns the label after connect, so the raw
      # interpolation placeholder must never survive to the screen.
      assert_no_text "%{minutes}"
    end

    # Rewind the start timestamp: only a live controller recomputes the label,
    # a server-rendered string would sit at zero forever.
    page.execute_script(<<~JS, 10.minutes.ago.iso8601)
      document
        .querySelector("[data-kitchen-order='#{order.id}'] .kitchen-order-elapsed")
        .setAttribute("data-elapsed-start-value", arguments[0])
    JS

    within "[data-kitchen-order='#{order.id}']" do
      assert_text I18n.t("kitchen.waiting", minutes: 10)
    end
  end

  test "a waiter can also work the kitchen queue" do
    sign_in_waiter
    item = line_items(:cooking_cappuccino)

    visit kitchen_path

    within "#line_item_card_#{item.id}" do
      click_on I18n.t("kitchen.ready")
      assert_text I18n.t("kitchen.waiting_for_waiter")
    end
    assert_equal "ready", item.reload.status
  end
end
