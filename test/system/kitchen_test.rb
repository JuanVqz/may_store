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
