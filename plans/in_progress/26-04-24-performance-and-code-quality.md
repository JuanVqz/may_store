# Performance & Code Quality Improvements

**Goal:** Fix N+1 queries, consolidate params handling, extract repeated view patterns, add missing model predicates, remove redundant broadcasts, and add missing validations. No new features.

**Branch:** `chore/code_review_improvements`

---

## Findings Summary

| # | Category | Severity | Description |
|---|----------|----------|-------------|
| 1 | N+1 | High | `TablesController` loads orders without `includes(:line_items)` — `readiness_counts` hits DB per order |
| 2 | N+1 | High | `TakeoutsController` same issue |
| 3 | N+1 | Medium | `OrdersController#show` eager loads `product_components` but not their `component` — N+1 in customization form |
| 4 | N+1 | Medium | `build_components` queries `Current.store.components` instead of product's own components |
| 5 | Params | Medium | `line_items_controller` uses `to_unsafe_h` bypassing Strong Params; `special_notes` pulled raw outside `line_item_params` |
| 6 | Model | Medium | `Order#allows_item_addition?` predicate lives in controller conditional, belongs on model |
| 7 | Model | Low | `add_item!` manually broadcasts to kitchen — redundant since LineItem callback already does it |
| 8 | Views | Medium | Ingredient/extra component display duplicated in `_line_item.html.erb` and `kitchen/_line_item_card.html.erb` |
| 9 | Validations | Low | `ProductComponent` missing presence validations; `LineItemComponent` missing presence validations |

---

## Task 1: Fix N+1 in TablesController and TakeoutsController

`readiness_counts` checks `line_items.loaded?` and uses a GROUP BY if not — so each order fires one extra query. With `includes(:line_items)` it uses in-memory data, zero extra queries.

- [ ] **Step 1: Fix TablesController**

```ruby
# app/controllers/tables_controller.rb
def index
  @spots = Current.store.spots.tables.where(active: true).order(:position)
  @active_orders = Current.store.orders
                           .where.not(status: [:closed, :cancelled])
                           .includes(:line_items)
                           .index_by(&:spot_id)
end
```

- [ ] **Step 2: Fix TakeoutsController**

```ruby
# app/controllers/takeouts_controller.rb
def index
  @spot = Spot.takeout_for(Current.store)
  @orders = @spot.orders
                 .where.not(status: [:closed, :cancelled])
                 .includes(:line_items)
                 .order(created_at: :desc)
end
```

- [ ] **Step 3: Run tests**

```bash
bin/rails test
```

- [ ] **Step 4: Commit**

---

## Task 2: Fix N+1 in OrdersController#show — products eager load

`includes(:product_components)` doesn't load the `component` record inside each `product_component`, causing N+1 in `_customization_form.html.erb`.

- [ ] **Step 1: Fix eager load chain**

```ruby
# app/controllers/orders_controller.rb — inside show, replace:
@products = @category&.products&.active&.available&.includes(:product_components) || Product.none
# with:
@products = @category&.products&.active&.available&.includes(product_components: :component) || Product.none
```

- [ ] **Step 2: Run tests**

- [ ] **Step 3: Commit**

---

## Task 3: Fix params handling in LineItemsController

Two problems: `to_unsafe_h` bypasses Strong Params; `special_notes` pulled raw from `params` instead of going through `line_item_params`.

- [ ] **Step 1: Update `line_item_params` and add dedicated param methods**

```ruby
# app/controllers/line_items_controller.rb

def line_item_params
  params.require(:line_item).permit(:product_id, :special_notes)
end

def ingredient_portions
  params.permit(ingredients: {}).fetch(:ingredients, {})
end

def extra_quantities
  params.permit(extras: {}).fetch(:extras, {}).select { |_, qty| qty.to_i > 0 }
end
```

- [ ] **Step 2: Update `create` to use `line_item_params[:special_notes]`**

```ruby
def create
  product = Current.store.products.find(line_item_params[:product_id])
  notes = line_item_params[:special_notes].presence
  # rest unchanged
end
```

- [ ] **Step 3: Update `build_components` to use new param methods and product's own components**

```ruby
def build_components(line_item, product)
  product.product_components.ingredient.includes(:component).each do |pc|
    portion = ingredient_portions[pc.component_id.to_s].presence || 1.0
    LineItemComponent.create!(
      line_item: line_item,
      component: pc.component,
      component_type: :ingredient,
      portion: portion.to_f,
      unit_price_cents: 0
    )
  end

  if extra_quantities.any?
    extras_by_component_id = product.product_components.extra.includes(:component).index_by(&:component_id)

    extra_quantities.each do |component_id, quantity|
      pc = extras_by_component_id[component_id.to_i]
      next unless pc

      quantity.to_i.times do
        LineItemComponent.create!(
          line_item: line_item,
          component: pc.component,
          component_type: :extra,
          portion: 1.0,
          unit_price_cents: pc.component.price_cents
        )
      end
    end
  end
end
```

This also fixes the N+1 from task 4 — extras now come from product's own components (already scoped), not a second store-wide query.

- [ ] **Step 4: Run tests**

- [ ] **Step 5: Commit**

---

## Task 4: Move `allows_item_addition?` predicate to Order model

Controller has inline `if @order.open? || @order.cooking? || @order.ready? || @order.delivered?` — business logic belongs on the model.

- [ ] **Step 1: Add predicate to Order**

```ruby
# app/models/order.rb
def allows_item_addition?
  open? || cooking? || ready? || delivered?
end
```

- [ ] **Step 2: Update OrdersController#show**

```ruby
if @order.allows_item_addition?
  @categories = Current.store.categories.active.ordered
  # ...
end
```

- [ ] **Step 3: Run tests**

- [ ] **Step 4: Commit**

---

## Task 5: Remove redundant broadcast from `Order#add_item!`

`add_item!` manually calls `broadcast_refresh_to "store_#{store_id}_kitchen"` after creating a LineItem. But `LineItem::Stateful` already has an `after_update_commit :broadcast_refreshes` — and `after_create_commit` would also fire if present. Check: the callback fires on `update`, not `create`. So the manual call IS needed for the create case. However, the LineItem callback fires `after_update_commit` only — meaning the `create!` in `add_item!` does NOT trigger it.

**Decision:** Keep the manual broadcast in `add_item!` but document why. Alternatively, change `LineItem::Stateful` to use `after_save_commit` to cover both create and update, then remove the manual broadcast.

- [ ] **Step 1: Change `after_update_commit` to `after_save_commit` in `LineItem::Stateful`**

```ruby
# app/models/line_item/stateful.rb
included do
  after_save :check_order_status, if: :saved_change_to_status?
  after_save_commit :broadcast_refreshes, if: :saved_change_to_status?
end
```

- [ ] **Step 2: Remove manual broadcast from `Order#add_item!`**

```ruby
def add_item!(product:, special_notes: nil)
  update!(status: :cooking) if ready? || delivered?

  item = line_items.create!(
    product: product,
    status: :cooking,
    base_price_cents: product.base_price_cents,
    special_notes: special_notes
  )
  item.calculate_total!
  item
end
```

- [ ] **Step 3: Run tests — verify kitchen broadcasts still fire**

- [ ] **Step 4: Commit**

---

## Task 6: Extract ingredient/extra display into shared partial

Same pattern duplicated in `_line_item.html.erb` (lines 9–22) and `kitchen/_line_item_card.html.erb` (lines 41–63).

- [ ] **Step 1: Create `app/views/line_items/_components.html.erb`**

```erb
<%# locals: (item:, modified_only: false) %>
<% ingredients = item.line_item_components.select(&:ingredient?) %>
<% extras = item.line_item_components.select(&:extra?) %>

<% if ingredients.any? %>
  <% to_show = modified_only ? ingredients.select { |c| c.portion.to_f != 1.0 } : ingredients %>
  <% if to_show.any? %>
    <div class="text-sm text-muted-foreground mt-0.5">
      <% if modified_only %>
        <% to_show.each do |c| %>
          <div><%= c.component.name %>: <%= c.portion_label %> *</div>
        <% end %>
      <% else %>
        <%= to_show.map { |c| "#{c.component.name}: #{c.portion_label}" }.join(", ") %>
      <% end %>
    </div>
  <% elsif modified_only %>
    <div class="text-sm text-muted-foreground"><%= t("line_item.standard_preparation") %></div>
  <% end %>
<% end %>

<% if extras.any? %>
  <div class="text-sm text-muted-foreground">
    <% extras.group_by(&:component_id).each do |_, group| %>
      <% wrapper_tag = modified_only ? :div : :span %>
      <%= content_tag wrapper_tag do %>+ <%= group.first.component.name %> x<%= group.size %><% end %>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 2: Replace duplicated code in `_line_item.html.erb`**

Replace the ingredients/extras block with:
```erb
<%= render "line_items/components", item: item %>
```

- [ ] **Step 3: Replace duplicated code in `kitchen/_line_item_card.html.erb`**

Replace the ingredients/extras block with:
```erb
<%= render "line_items/components", item: item, modified_only: true %>
```

- [ ] **Step 4: Run tests + visual check**

- [ ] **Step 5: Commit**

---

## Task 7: Add missing validations

- [ ] **Step 1: Add to `ProductComponent`**

```ruby
# app/models/product_component.rb
validates :product_id, :component_id, :component_type, presence: true
```

- [ ] **Step 2: Add to `LineItemComponent`**

```ruby
# app/models/line_item_component.rb
validates :line_item_id, :component_id, :component_type, presence: true
validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
```

- [ ] **Step 3: Run tests**

- [ ] **Step 4: Commit**

---

## Done When

- No N+1 on tables/takeouts index pages
- No N+1 on customization form product components
- Strong Params used throughout `LineItemsController`
- `Order#allows_item_addition?` on model
- Kitchen broadcasts fire on item create without manual call in `add_item!`
- Ingredient/extra display in single partial
- Presence validations on `ProductComponent` and `LineItemComponent`
- Full test suite passes: `bin/rails test`
