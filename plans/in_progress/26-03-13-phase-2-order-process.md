# Phase 2: Order Process (Waiter Ordering Flow)

## Goal
Build all waiter-facing screens: login view, table selection, product browsing, customization, order summary, active order management.

## Reference
- `docs/wireframes.md` — Screens 1-6, 8
- `docs/models.md` — Order/LineItem/LineItemComponent flows

---

## Steps

### 1. Login View (Screen 1)
- [x] Login form view (`sessions/new.html.erb`)
- [x] Application layout with store branding, navbar, flash messages
- [x] Separate login layout (no navbar)
- [x] Responsive mobile-first CSS

### 2. Table Selection (Screen 2)
- [x] `TablesController#index` — grid of tables for current store
- [x] Show table status (available, has active order with status color)
- [x] Click table -> new order or view active order
- [x] Navbar with user info, role, logout
- [x] Status legend

### 3. Product Browser (Screen 3)
- [x] `OrderProductsController#index`
- [x] Category tabs with active state
- [x] Product cards with name, description, price, image placeholder
- [x] Filter by category
- [x] "Customize" or "Add to Order" per product

### 4. Product Customization (Screen 4)
- [x] Ingredient portion radio buttons: `(Sin) (1/4) (1/2) (3/4) [Normal]`
- [x] Required ingredients omit "Sin" button
- [x] Extras number input for quantity
- [x] Special notes text field
- [x] "Add to Order" submit
- [ ] Stimulus controller for interactive UI (live price calc, radio styling)

### 5. Order Summary / Show (Screen 5)
- [x] Show all line items with customizations (ingredients, extras, notes)
- [x] Per-item price and status badges
- [x] Order total
- [x] "Confirm Order" button (sends to kitchen)
- [x] "Add More Items" button
- [x] Remove item before confirmation

### 6. Active Order View (Screen 6)
- [x] Show order after confirmation (COOKING state)
- [x] Per-item status badges with colors
- [x] "Add More Items" button (adds items as COOKING)
- [x] "Cancel Order" with turbo_confirm dialog
- [x] "Request Bill" placeholder (when DELIVERED)
- [x] Mark ready / Mark delivered buttons per item
- [ ] Real-time updates via Turbo Streams

### 7. Mixed Item Statuses (Screen 8)
- [ ] Handle orders where items are in different states
- [ ] Mark individual items as delivered
- [ ] Show which items are ready for pickup

### 8. Stimulus Controllers
- [ ] Product customization (portions, extras, price calc)
- [ ] Order confirmation dialog
- [ ] Flash message auto-dismiss

### 9. Turbo Integration
- [ ] Turbo Frames for product browsing within order flow
- [ ] Turbo Streams for real-time order/item status updates
- [ ] Broadcast status changes to relevant screens

### 10. Tests
- [ ] Controller tests for TablesController, OrdersController
- [ ] Integration tests for order creation flow
- [ ] System tests for customization UI (if feasible)

---

## Done When
- Waiter can log in, select table, browse products, customize, and create order
- Order confirmation sends items to COOKING status
- Active order shows real-time status updates
- Add more items works on cooking/ready orders
- Order cancellation works with confirmation
- All views use I18n Spanish strings
- Tests pass
