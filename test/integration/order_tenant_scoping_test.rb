require "test_helper"

# Every endpoint that acts on an order or on one of its items finds the record
# through Current.store. One unscoped lookup would hand another store's order to
# whoever guessed its id, so the whole surface is asserted here rather than one
# endpoint at a time in each controller's own test.
class OrderTenantScopingTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:cafe_delicias)
    post login_url(subdomain: @store.subdomain),
         params: { employee_number: "EMP-001", password: "password123" }

    other_store = stores(:mi_cafe)
    @foreign_order = other_store.orders.create!(
      spot: other_store.spots.create!(name: "Mesa 1", spot_type: :dine_in, position: 1, active: true),
      user: users(:other_store_waiter),
      status: :cooking,
      opened_at: Time.current
    )
    foreign_category = other_store.categories.create!(name: "Bebidas", station: :bar, position: 1)
    foreign_product = other_store.products.create!(
      category: foreign_category, name: "Cafe", base_price_cents: 1000, available: true
    )
    @foreign_item = @foreign_order.line_items.create!(
      product: foreign_product,
      status: :cooking,
      base_price_cents: 1000
    )
  end

  test "another store's order is out of reach on every read" do
    assert_not_found { get order_url(@foreign_order, subdomain: @store.subdomain) }
    assert_not_found { get order_bill_url(@foreign_order, subdomain: @store.subdomain) }
    assert_not_found { get order_receipt_url(@foreign_order, subdomain: @store.subdomain) }
    assert_not_found { get order_kitchen_ticket_url(@foreign_order, subdomain: @store.subdomain) }
  end

  test "another store's order cannot be confirmed, cancelled or paid" do
    assert_not_found { post order_confirmation_url(@foreign_order, subdomain: @store.subdomain) }
    assert_not_found { post order_cancellation_url(@foreign_order, subdomain: @store.subdomain) }
    assert_not_found do
      post order_payments_url(@foreign_order, subdomain: @store.subdomain),
           params: { payment_method_id: payment_methods(:efectivo).id }
    end

    assert @foreign_order.reload.cooking?
  end

  test "another store's line item cannot be advanced or cancelled" do
    assert_not_found do
      post order_line_item_readiness_url(@foreign_order, @foreign_item, subdomain: @store.subdomain)
    end
    assert_not_found do
      post order_line_item_delivery_url(@foreign_order, @foreign_item, subdomain: @store.subdomain)
    end
    assert_not_found do
      post order_line_item_cancellation_url(@foreign_order, @foreign_item, subdomain: @store.subdomain)
    end
    assert_not_found do
      delete order_line_item_url(@foreign_order, @foreign_item, subdomain: @store.subdomain)
    end

    assert @foreign_item.reload.cooking?
  end

  # The order id is scoped, so a local order with someone else's item id is a
  # 404 too: the item is looked up through the order, never on its own.
  test "an item id from another order is not reachable through a local order" do
    local_order = orders(:cooking_order)

    assert_not_found do
      post order_line_item_readiness_url(local_order, @foreign_item, subdomain: @store.subdomain)
    end
  end

  private

  def assert_not_found
    yield
    assert_response :not_found
  end
end
