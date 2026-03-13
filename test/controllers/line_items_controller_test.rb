require "test_helper"

class LineItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
    @order = orders(:open_order)
    @product = products(:cappuccino)
  end

  test "new shows customization form" do
    get new_order_line_item_url(@order, product_id: @product.id, subdomain: @store.subdomain)
    assert_response :success
    assert_match @product.name, response.body
    assert_match "Espresso Shot", response.body
  end

  test "create adds item to open order" do
    assert_difference "LineItem.count", 1 do
      post order_line_items_url(@order, subdomain: @store.subdomain), params: {
        line_item: { product_id: @product.id },
        ingredients: { components(:espresso_shot).id.to_s => "1.0", components(:steamed_milk).id.to_s => "0.5" },
        extras: { components(:extra_chocolate).id.to_s => "2" }
      }
    end
    item = LineItem.last
    assert_equal "ordering", item.status
    assert_equal @product.base_price_cents + 2000, item.total_price_cents
    assert_redirected_to order_products_url(@order, subdomain: @store.subdomain)
  end

  test "create adds item to cooking order as cooking" do
    cooking_order = orders(:cooking_order)
    assert_difference "LineItem.count", 1 do
      post order_line_items_url(cooking_order, subdomain: @store.subdomain), params: {
        line_item: { product_id: @product.id }
      }
    end
    assert_equal "cooking", LineItem.last.status
  end

  test "destroy removes item" do
    item = line_items(:ordering_americano)
    assert_difference "LineItem.count", -1 do
      delete order_line_item_url(@order, item, subdomain: @store.subdomain)
    end
    assert_redirected_to order_url(@order, subdomain: @store.subdomain)
  end

  test "ready marks item as ready" do
    item = line_items(:cooking_cappuccino)
    patch ready_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    assert_equal "ready", item.reload.status
  end

  test "deliver marks item as delivered" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    patch deliver_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    assert_equal "delivered", item.reload.status
  end
end
