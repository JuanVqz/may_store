require "test_helper"

class LineItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    @user = users(:waiter_juan)
    post login_url(subdomain: @store.subdomain), params: { employee_number: "EMP-001", password: "password123" }
    @order = orders(:open_order)
    @product = products(:cappuccino)
  end

  test "new returns customization form partial" do
    get new_order_line_item_url(@order, product_id: @product.id, subdomain: @store.subdomain)
    assert_response :success
    assert_match "Espresso Shot", response.body
    assert_match 'data-controller="customization"', response.body
  end

  test "create adds item to open order via html" do
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
    assert_redirected_to order_url(@order, subdomain: @store.subdomain)
  end

  test "create responds with turbo stream" do
    assert_difference "LineItem.count", 1 do
      post order_line_items_url(@order, subdomain: @store.subdomain),
        params: {
          line_item: { product_id: @product.id },
          ingredients: { components(:espresso_shot).id.to_s => "1.0" }
        },
        as: :turbo_stream
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_match "order_items", response.body
    assert_match "order_summary", response.body
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

  test "create transitions ready order back to cooking" do
    ready_order = orders(:ready_order)
    assert_equal "ready", ready_order.status
    post order_line_items_url(ready_order, subdomain: @store.subdomain), params: {
      line_item: { product_id: @product.id }
    }
    assert_equal "cooking", ready_order.reload.status
    assert_equal "cooking", LineItem.last.status
  end

  test "create transitions delivered order back to cooking" do
    delivered_order = orders(:delivered_order)
    assert_equal "delivered", delivered_order.status
    post order_line_items_url(delivered_order, subdomain: @store.subdomain), params: {
      line_item: { product_id: @product.id }
    }
    assert_equal "cooking", delivered_order.reload.status
    assert_equal "cooking", LineItem.last.status
  end

  test "destroy removes item via html" do
    item = line_items(:ordering_americano)
    assert_difference "LineItem.count", -1 do
      delete order_line_item_url(@order, item, subdomain: @store.subdomain)
    end
    assert_redirected_to order_url(@order, subdomain: @store.subdomain)
  end

  test "destroy responds with turbo stream" do
    item = line_items(:ordering_americano)
    assert_difference "LineItem.count", -1 do
      delete order_line_item_url(@order, item, subdomain: @store.subdomain), as: :turbo_stream
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_match "line_item_#{item.id}", response.body
    assert_match "order_summary", response.body
  end

  test "ready marks item as ready and tracks actor" do
    item = line_items(:cooking_cappuccino)
    patch ready_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    item.reload
    assert_equal "ready", item.status
    assert_equal @user, item.ready_by
  end

  test "ready redirects back" do
    item = line_items(:cooking_cappuccino)
    patch ready_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    assert_response :redirect
  end

  test "deliver marks item as delivered and tracks actor" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    patch deliver_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    item.reload
    assert_equal "delivered", item.status
    assert_equal @user, item.delivered_by
  end

  test "deliver redirects back" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    patch deliver_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    assert_response :redirect
  end

  test "create saves special_notes from customization form" do
    product = products(:americano)
    post order_line_items_url(@order, subdomain: @store.subdomain), params: {
      line_item: { product_id: product.id },
      special_notes: "Sin hielo"
    }
    item = @order.line_items.last
    assert_equal "Sin hielo", item.special_notes
  end

  test "create saves special_notes via add_item path for non-open orders" do
    order = orders(:ready_order)
    product = products(:americano)
    post order_line_items_url(order, subdomain: @store.subdomain), params: {
      line_item: { product_id: product.id },
      special_notes: "Extra caliente"
    }
    item = order.line_items.order(created_at: :desc).first
    assert_equal "Extra caliente", item.special_notes
    assert_equal "cooking", order.reload.status
  end

  test "cancel marks item as cancelled and tracks actor" do
    item = line_items(:cooking_cappuccino)
    patch cancel_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    item.reload
    assert_equal "cancelled", item.status
    assert_equal @user, item.cancelled_by
  end

  test "ready rejects non-cooking item" do
    item = line_items(:ordering_americano)
    patch ready_order_line_item_url(@order, item, subdomain: @store.subdomain)
    assert_redirected_to order_url(@order, subdomain: @store.subdomain)
    assert_equal "ordering", item.reload.status
  end

  test "deliver rejects cooking item" do
    item = line_items(:cooking_cappuccino)
    patch deliver_order_line_item_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    assert_redirected_to order_url(orders(:cooking_order), subdomain: @store.subdomain)
    assert_equal "cooking", item.reload.status
  end

  # The item is left READY so the request reaches the paid-order guard rather
  # than the status check, which would refuse a delivered item regardless.
  test "cancel refuses a ready item on a closed order and says why" do
    order = orders(:cooking_order)
    order.line_items.each { |li| li.mark_ready!(by: users(:waiter_juan)) }
    item = order.line_items.first
    order.reload.payments.create!(payment_method: payment_methods(:efectivo),
                                  amount_cents: order.total_cents,
                                  received_cents: order.total_cents, paid_at: Time.current)
    order.close!

    patch cancel_order_line_item_url(order, item, subdomain: @store.subdomain)

    assert_redirected_to order_url(order, subdomain: @store.subdomain)
    assert_equal I18n.t("line_item.cannot_cancel_paid"), flash[:alert]
    assert_not item.reload.cancelled?
  end

  # A generic alert would leave the cashier guessing which rule they hit, so the
  # status refusal names the status instead of borrowing the payment message.
  test "cancel names the status when the item itself cannot be cancelled" do
    item = line_items(:delivered_latte)

    patch cancel_order_line_item_url(orders(:delivered_order), item, subdomain: @store.subdomain)

    assert_equal I18n.t("line_item.cannot_cancel_status", status: item.status_label.downcase),
                 flash[:alert]
    assert_equal "delivered", item.reload.status
  # A customer who changes their mind as the drink reaches the pass should not
  # need the kitchen to cancel it for them.
  test "a ready item can be cancelled from the order screen" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.update!(status: :ready)

    patch cancel_order_line_item_url(order, item, subdomain: @store.subdomain)

    assert item.reload.cancelled?
    assert_not_nil item.cancelled_by
  end

  test "the order screen offers the cancel button on a ready item" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.update!(status: :ready)

    get order_url(order, subdomain: @store.subdomain)

    assert_response :success
    assert_match cancel_order_line_item_path(order, item), response.body
  end
end
