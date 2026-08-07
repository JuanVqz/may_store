require "application_system_test_case"

class TakeoutTest < ApplicationSystemTestCase
  setup do
    sign_in_waiter
  end

  test "the takeout screen is empty when there are no active takeout orders" do
    visit takeouts_path

    assert_text I18n.t("takeouts.no_orders")
  end

  test "starting a new takeout order" do
    visit takeouts_path

    assert_difference "Order.count", 1 do
      click_on I18n.t("takeouts.new_order")
      assert_text I18n.t("order.no_items")
    end

    assert_equal spots(:para_llevar), Order.order(:created_at).last.spot
  end

  test "an active takeout order is listed" do
    order = create_takeout_order

    visit takeouts_path

    assert_text order.code
    assert_no_text I18n.t("takeouts.no_orders")
  end

  test "a takeout order links through to the order screen" do
    order = create_takeout_order

    visit takeouts_path
    click_on order.code

    assert_current_path order_path(order)
  end

  test "a closed takeout order drops off the list" do
    order = create_takeout_order
    order.update!(status: :closed, closed_at: Time.current)

    visit takeouts_path

    assert_text I18n.t("takeouts.no_orders")
  end

  test "the takeout order breadcrumb returns to the takeout list" do
    order = create_takeout_order

    visit order_path(order)
    within "nav" do
      click_on I18n.t("takeouts.title")
    end

    assert_current_path takeouts_path
  end

  test "takeout orders do not appear on the tables screen" do
    order = create_takeout_order

    visit tables_path

    assert_no_text order.code
  end

  private
    def create_takeout_order
      Order.create!(
        store: stores(:cafe_delicias),
        spot: spots(:para_llevar),
        user: users(:waiter_juan),
        status: :open,
        opened_at: Time.current
      )
    end
end
