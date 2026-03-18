# Model Concerns Extraction

Extract behavioral concerns from Order and LineItem following the fizzy adjective-style pattern (`Model::Behavior`), with one concern per file under `app/models/model_name/`.

## Concerns to Extract

### 1. `Order::Stateful` (`app/models/order/stateful.rb`)

All state machine logic moves here:

```ruby
module Order::Stateful
  extend ActiveSupport::Concern

  included do
    after_update_commit :broadcast_refreshes, if: :saved_change_to_status?
  end

  STATUS_COLORS = {
    "open" => "#FCD34D",
    "cooking" => "#F97316",
    "ready" => "#22C55E",
    "delivered" => "#A855F7",
    "closed" => "#6B7280",
    "cancelled" => "#EF4444"
  }.freeze

  def status_label
    I18n.t("order_statuses.#{status}")
  end

  def status_color
    STATUS_COLORS[status]
  end

  def confirm!
    raise ActiveRecord::RecordInvalid, self if line_items.empty?

    transaction do
      update!(status: :cooking, cooking_at: Time.current)
      line_items.where(status: :ordering).update_all(status: :cooking)
    end

    broadcast_refresh_to "store_#{store_id}_kitchen"
  end

  def check_ready!
    return unless cooking?
    return cancel! if line_items.where.not(status: :cancelled).none?

    unfinished = line_items.where.not(status: [:ready, :delivered, :cancelled]).exists?
    update!(status: :ready, ready_at: Time.current) unless unfinished
  end

  def check_delivered!
    return unless ready?
    return cancel! if line_items.where.not(status: :cancelled).none?

    unfinished = line_items.where.not(status: [:delivered, :cancelled]).exists?
    update!(status: :delivered, delivered_at: Time.current) unless unfinished
  end

  def close!
    update!(status: :closed, closed_at: Time.current)
  end

  def cancel!
    transaction do
      update!(status: :cancelled, cancelled_at: Time.current)
      line_items.where(status: [:ordering, :cooking, :ready])
                .update_all(status: :cancelled)
    end
  end

  private

  def broadcast_refreshes
    broadcast_refresh_to "order_#{id}"
    broadcast_refresh_to "store_#{store_id}_tables"
    broadcast_refresh_to "store_#{store_id}_takeouts"
  end
end
```

### 2. `Order::CodeGenerable` (`app/models/order/code_generable.rb`)

Code generation logic, fully self-contained:

```ruby
module Order::CodeGenerable
  extend ActiveSupport::Concern

  included do
    before_create :generate_code
  end

  private

  def generate_code
    return if code.present?

    prefix = store.order_prefix
    year_month = Time.current.strftime("%y%m")

    retries = 3
    begin
      OrderCounter.find_or_create_by!(store_id: store_id, year_month: year_month) do |c|
        c.current_sequence = 0
      end
    rescue ActiveRecord::RecordNotUnique
      retry if (retries -= 1) > 0
      raise
    end

    sql = OrderCounter.sanitize_sql_array([
      "UPDATE order_counters SET current_sequence = current_sequence + 1, updated_at = NOW() " \
      "WHERE store_id = ? AND year_month = ? RETURNING current_sequence",
      store_id, year_month
    ])
    seq = OrderCounter.connection.select_value(sql)

    self.code = "#{prefix}#{year_month}-#{seq.to_s.rjust(3, '0')}"
  end
end
```

### 3. `LineItem::Stateful` (`app/models/line_item/stateful.rb`)

Item state machine, transitions, and order status cascading:

```ruby
module LineItem::Stateful
  extend ActiveSupport::Concern

  included do
    after_update :check_order_status, if: :saved_change_to_status?
    after_update_commit :broadcast_refreshes, if: :saved_change_to_status?
  end

  STATUS_COLORS = {
    "ordering" => "#FCD34D",
    "cooking" => "#F97316",
    "ready" => "#22C55E",
    "delivered" => "#A855F7",
    "cancelled" => "#EF4444"
  }.freeze

  def status_label
    I18n.t("item_statuses.#{status}")
  end

  def status_color
    STATUS_COLORS[status]
  end

  def mark_ready!(by: nil)
    raise InvalidTransition, "Can only mark cooking items as ready" unless cooking?
    update!(status: :ready, ready_by: by)
  end

  def mark_delivered!(by: nil)
    raise InvalidTransition, "Can only deliver ready items" unless ready?
    update!(status: :delivered, delivered_by: by)
  end

  def cancel!(by: nil)
    raise InvalidTransition, "Cannot cancel #{status} items" if cancelled? || delivered?
    update!(status: :cancelled, cancelled_by: by)
  end

  private

  def broadcast_refreshes
    broadcast_refresh_to "order_#{order_id}"
    broadcast_refresh_to "store_#{order.store_id}_kitchen"
    broadcast_refresh_to "store_#{order.store_id}_tables"
    broadcast_refresh_to "store_#{order.store_id}_takeouts"
  end

  def check_order_status
    order.check_ready!
    order.check_delivered!
  end
end
```

## Resulting Base Models

### `Order` after extraction

```ruby
class Order < ApplicationRecord
  include PriceCents
  include Order::Stateful
  include Order::CodeGenerable

  belongs_to :store
  belongs_to :spot
  belongs_to :user
  has_many :line_items, dependent: :destroy
  has_many :payments, dependent: :destroy

  enum :status, {
    open: "open", cooking: "cooking", ready: "ready",
    delivered: "delivered", closed: "closed", cancelled: "cancelled"
  }

  price_in_cents :total

  def recalculate_total!
    update_columns(total_cents: line_items.reload.where.not(status: :cancelled).sum(:total_price_cents))
  end

  def add_item!(product:, special_notes: nil)
    update!(status: :cooking) if ready? || delivered?

    item = line_items.create!(
      product: product,
      status: :cooking,
      base_price_cents: product.base_price_cents,
      special_notes: special_notes
    )
    item.calculate_total!
    broadcast_refresh_to "store_#{store_id}_kitchen"
    item
  end

  def total_paid_cents
    payments.sum(:amount_cents)
  end

  def remaining_cents
    total_cents - total_paid_cents
  end

  def fully_paid?
    remaining_cents <= 0
  end

  def readiness_counts
    active = line_items.where.not(status: :cancelled)
    total_count = active.count
    ready_count = active.where(status: [:ready, :delivered]).count
    delivered_count = active.where(status: :delivered).count
    { ready: ready_count, delivered: delivered_count, total: total_count }
  end
end
```

### `LineItem` after extraction

```ruby
class LineItem < ApplicationRecord
  include PriceCents
  include LineItem::Stateful

  class InvalidTransition < StandardError; end

  belongs_to :order
  belongs_to :product
  belongs_to :ready_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  belongs_to :delivered_by, class_name: "User", optional: true
  has_many :line_item_components, dependent: :destroy

  enum :status, {
    ordering: "ordering", cooking: "cooking", ready: "ready",
    delivered: "delivered", cancelled: "cancelled"
  }

  after_save :recalculate_order_total, if: :saved_change_to_total_price_cents?
  after_destroy :recalculate_order_total

  price_in_cents :base_price, :total_price

  def calculate_total!
    extras_total = line_item_components
                     .where(component_type: :extra)
                     .sum(:unit_price_cents)
    self.total_price_cents = base_price_cents + extras_total
    save!
  end

  private

  def recalculate_order_total
    order.recalculate_total!
  end
end
```

## What stays where

| Logic | Location | Reason |
|-------|----------|--------|
| Status transitions, colors, labels | `Stateful` concerns | Core state machine behavior |
| Code generation + OrderCounter | `Order::CodeGenerable` | Self-contained, no overlap |
| `recalculate_total!`, payment helpers | `Order` base | Simple one-liners |
| `add_item!` | `Order` base | Mixes status + line item creation |
| `calculate_total!` | `LineItem` base | Single method, straightforward |
| `recalculate_order_total` callback | `LineItem` base | Price-related, not status |
| Broadcast callbacks | `Stateful` concerns | Tied to status changes |

## File structure

```
app/models/
  order.rb
  order/
    stateful.rb
    code_generable.rb
  line_item.rb
  line_item/
    stateful.rb
```

## Testing

Existing model tests should pass unchanged — this is a pure refactor with no behavior changes. Run the full test suite to verify.
