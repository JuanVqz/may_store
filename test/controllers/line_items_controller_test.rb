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
    post order_line_item_readiness_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    item.reload
    assert_equal "ready", item.status
    assert_equal @user, item.ready_by
  end

  test "ready redirects back" do
    item = line_items(:cooking_cappuccino)
    post order_line_item_readiness_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    assert_response :redirect
  end

  test "deliver marks item as delivered and tracks actor" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    post order_line_item_delivery_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    item.reload
    assert_equal "delivered", item.status
    assert_equal @user, item.delivered_by
  end

  test "deliver redirects back" do
    item = line_items(:cooking_cappuccino)
    item.mark_ready!
    post order_line_item_delivery_url(orders(:cooking_order), item, subdomain: @store.subdomain)
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
    post order_line_item_cancellation_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    item.reload
    assert_equal "cancelled", item.status
    assert_equal @user, item.cancelled_by
  end

  test "ready rejects non-cooking item" do
    item = line_items(:ordering_americano)
    post order_line_item_readiness_url(@order, item, subdomain: @store.subdomain)
    assert_redirected_to order_url(@order, subdomain: @store.subdomain)
    assert_equal "ordering", item.reload.status
  end

  test "deliver rejects cooking item" do
    item = line_items(:cooking_cappuccino)
    post order_line_item_delivery_url(orders(:cooking_order), item, subdomain: @store.subdomain)
    assert_redirected_to order_url(orders(:cooking_order), subdomain: @store.subdomain)
    assert_equal "cooking", item.reload.status
  end

  # The item is left READY so the request reaches the paid-order guard rather
  # than the status check, which would refuse a delivered item regardless.
  test "cancel refuses a ready item on a closed order and says why" do
    order = orders(:cooking_order)
    order.line_items.each { |li| li.mark_ready!(by: users(:waiter_juan)) }
    item = line_items(:cooking_cappuccino)
    order.reload.payments.create!(payment_method: payment_methods(:efectivo),
                                  amount_cents: order.total_cents,
                                  received_cents: order.total_cents, paid_at: Time.current)
    order.close!

    post order_line_item_cancellation_url(order, item, subdomain: @store.subdomain)

    assert_redirected_to order_url(order, subdomain: @store.subdomain)
    assert_equal I18n.t("line_item.cannot_cancel_paid"), flash[:alert]
    assert_not item.reload.cancelled?
  end

  # A generic alert would leave the cashier guessing which rule they hit, so the
  # status refusal names the status instead of borrowing the payment message.
  test "cancel names the status when the item itself cannot be cancelled" do
    item = line_items(:delivered_latte)

    post order_line_item_cancellation_url(orders(:delivered_order), item, subdomain: @store.subdomain)

    assert_equal I18n.t("line_item.cannot_cancel_status", status: item.status_label.downcase),
                 flash[:alert]
    assert_equal "delivered", item.reload.status
  end

  # A customer who changes their mind as the drink reaches the pass should not
  # need the kitchen to cancel it for them.
  test "a ready item can be cancelled from the order screen" do
    order = orders(:cooking_order)
    item = line_items(:cooking_cappuccino)
    item.update!(status: :ready)

    post order_line_item_cancellation_url(order, item, subdomain: @store.subdomain)

    assert item.reload.cancelled?
    assert_not_nil item.cancelled_by
  end

  test "the order screen offers the cancel button on a ready item" do
    order = orders(:cooking_order)
    item = line_items(:cooking_cappuccino)
    item.update!(status: :ready)

    get order_url(order, subdomain: @store.subdomain)

    assert_response :success
    assert_match order_line_item_cancellation_path(order, item), response.body
  end

  # Paying before the food goes out is the normal case that leaves items READY on
  # a paid order, and the model refuses to cancel those: the total would fall below
  # what was already taken. So the new button has to disappear there too, or it is
  # a tap that can only ever produce an alert.
  test "the order screen hides the cancel button on a ready item once the order is paid" do
    order = orders(:cooking_order)
    item = line_items(:cooking_cappuccino)
    item.update!(status: :ready)
    order.payments.create!(payment_method: payment_methods(:efectivo),
                           amount_cents: order.total_cents,
                           received_cents: order.total_cents, paid_at: Time.current)

    get order_url(order, subdomain: @store.subdomain)

    assert_response :success
    assert_select "form[action=?]", order_line_item_cancellation_path(order, item), count: 0
    assert_select "form[action=?]", order_line_item_delivery_path(order, item)
  end

  test "cancelling records the default reason without asking for one" do
    order = orders(:cooking_order)
    item = order.line_items.first

    post order_line_item_cancellation_url(order, item, subdomain: @store.subdomain)

    assert_equal LineItem::DEFAULT_CANCELLATION_REASON, item.reload.cancellation_reason
  end

  test "update corrects the reason on a cancelled item" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.cancel!(by: users(:waiter_juan))

    patch order_line_item_url(order, item, subdomain: @store.subdomain),
          params: { line_item: { cancellation_reason: "kitchen_error" } }

    assert_equal "kitchen_error", item.reload.cancellation_reason
  end

  # The view hides the form on a live item, which is not a guard on the route: a
  # stale form would otherwise stamp a cancellation reason on an item that is
  # still being cooked, and any report grouping by reason would count it.
  test "update refuses to set a reason on an item that is not cancelled" do
    order = orders(:cooking_order)
    item = order.line_items.first

    patch order_line_item_url(order, item, subdomain: @store.subdomain),
          params: { line_item: { cancellation_reason: "kitchen_error" } }

    assert_equal I18n.t("line_item.reason_only_when_cancelled"), flash[:alert]
    assert_nil item.reload.cancellation_reason
    assert_equal "cooking", item.status
  end

  test "update rejects a reason outside the list" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.cancel!(by: users(:waiter_juan))

    patch order_line_item_url(order, item, subdomain: @store.subdomain),
          params: { line_item: { cancellation_reason: "because_i_said_so" } }

    assert_equal LineItem::DEFAULT_CANCELLATION_REASON, item.reload.cancellation_reason
  end

  # Only the reason is editable this way; nothing else about an item is.
  test "update ignores any other attribute" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.cancel!(by: users(:waiter_juan))

    before = item.total_price_cents

    patch order_line_item_url(order, item, subdomain: @store.subdomain),
          params: { line_item: { cancellation_reason: "duplicate", total_price_cents: 1 } }

    assert_equal "duplicate", item.reload.cancellation_reason
    assert_equal before, item.total_price_cents
  end

  # The active order screen filters cancelled items out entirely, so the only
  # places a cancelled item is visible are the bill and the closed order. The
  # selector lives there rather than somewhere it could never be seen.
  test "the bill offers the reason selector on a cancelled item" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.cancel!(by: users(:waiter_juan))

    get order_bill_url(order, subdomain: @store.subdomain)

    assert_response :success
    assert_match I18n.t("line_item.cancellation_reason"), response.body
    assert_match I18n.t("cancellation_reasons.kitchen_error"), response.body
  end

  # A NULL reason is "nobody said". Preselecting the first reason would show a
  # deliberate answer that nobody gave, and the form only submits on change, so
  # re-picking it would never write the row the screen already claims.
  test "the selector shows no reason for an item cancelled without one" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.cancel!(by: users(:waiter_juan))
    item.update_columns(cancellation_reason: nil)

    get order_bill_url(order, subdomain: @store.subdomain)

    assert_response :success
    assert_select "select##{ActionView::RecordIdentifier.dom_id(item, :cancellation_reason)}" do
      assert_select "option[selected]", count: 0
      assert_select "option[value='']", text: I18n.t("line_item.no_reason")
    end
  end

  test "the selector offers no blank once a reason is recorded" do
    order = orders(:cooking_order)
    item = order.line_items.first
    item.cancel!(by: users(:waiter_juan))

    get order_bill_url(order, subdomain: @store.subdomain)

    assert_select "select##{ActionView::RecordIdentifier.dom_id(item, :cancellation_reason)}" do
      assert_select "option[value='']", count: 0
      assert_select "option[selected]", text: I18n.t("cancellation_reasons.#{LineItem::DEFAULT_CANCELLATION_REASON}")
    end
  end

  test "an item that was not cancelled gets no reason selector" do
    order = orders(:cooking_order)

    get order_bill_url(order, subdomain: @store.subdomain)

    assert_response :success
    assert_no_match I18n.t("line_item.cancellation_reason"), response.body
  end
end
