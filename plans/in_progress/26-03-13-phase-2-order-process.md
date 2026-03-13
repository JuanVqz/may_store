# Phase 2: Order Process (Waiter Ordering Flow)

## Goal
Build all waiter-facing screens: login view, table selection, product browsing, customization, order summary, active order management.

## Reference
- `docs/wireframes.md` — Screens 1-6, 8
- `docs/models.md` — Order/LineItem/LineItemComponent flows

---

## Steps

### 1. Login View (Screen 1)
- [ ] Login form view (`sessions/new.html.erb`)
- [ ] Application layout with store branding
- [ ] Flash message display (alert/notice)
- [ ] Responsive mobile-first layout

### 2. Table Selection (Screen 2)
- [ ] `TablesController#index` — grid of tables for current store
- [ ] Show table status (available, has active order with status color)
- [ ] Click table -> new order or view active order
- [ ] Navbar with user info, role, logout

### 3. Product Browser (Screen 3)
- [ ] `ProductsController` or `OrdersController` flow
- [ ] Category tabs/sidebar
- [ ] Product cards with name, price, image placeholder
- [ ] Filter by category
- [ ] "Add to Order" button per product
- [ ] Show current order item count

### 4. Product Customization (Screen 4)
- [ ] Ingredient portion buttons: `(Sin) (1/4) (1/2) (3/4) [Normal]`
- [ ] Required ingredients omit "Sin" button
- [ ] Extras add/remove counter `[-] N [+]`
- [ ] Special notes text field
- [ ] Live price calculation (base + extras)
- [ ] "Add to Order" confirmation
- [ ] Stimulus controller for interactive UI

### 5. Order Summary (Screen 5)
- [ ] Show all line items with customizations
- [ ] Per-item price breakdown
- [ ] Order total
- [ ] Order notes field
- [ ] "Confirm Order" button (sends to kitchen)
- [ ] "Add More Items" button
- [ ] Remove item before confirmation

### 6. Active Order View (Screen 6)
- [ ] Show order after confirmation (COOKING state)
- [ ] Per-item status badges with colors
- [ ] "Add More Items" button (adds items as COOKING)
- [ ] "Cancel Order" with confirmation dialog
- [ ] "Request Bill" button (when DELIVERED)
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
