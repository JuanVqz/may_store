# MayStore - Database Seeds
#
# Version: 5.0
# Run: bin/rails db:seed
#
# Key points:
# - Account model for auth (has_secure_password), User model for profile + role
# - Roles: waiter, kitchen, admin
# - No status lookup tables (string enums on Order/LineItem)
# - No ComponentType table (string enum on ProductComponent/LineItemComponent)
# - Only total_cents on Order (no subtotal_cents)
# - Soft delete (deleted_at) on User, Product, Component, Category
# - CashClosing + CashClosingLine for admin cash audit
# - All user-facing strings via I18n (not in seeds)

# db/seeds.rb
# MayStore - Database Seeds v5.0
# ==============================

puts "Clearing existing data..."
CashClosingLine.delete_all if defined?(CashClosingLine)
CashClosing.delete_all if defined?(CashClosing)
LineItemComponent.delete_all
LineItem.delete_all
Payment.delete_all
Order.delete_all
PaymentMethod.delete_all
ProductComponent.delete_all
Component.delete_all
Product.delete_all
Category.delete_all
Spot.delete_all
Account.delete_all
User.delete_all
Store.delete_all

puts "Creating seed data..."

# Helper: convert dollars to cents
def to_cents(dollars)
  (dollars * 100).round
end

# ============================================
# STORE (Tenant)
# ============================================
store = Store.create!(
  name: "Cafe Delicias",
  subdomain: "cafe",
  order_prefix: "CFE",
  active: true
)
puts "Created store: #{store.name} (#{store.subdomain}.store.com)"

# ============================================
# USERS + ACCOUNTS
# ============================================
users_data = [
  { name: "Juan Perez", role: :waiter, employee_number: "EMP-001", email: "juan@cafe.com", phone: "555-0101" },
  { name: "Maria Garcia", role: :waiter, employee_number: "EMP-002", email: "maria@cafe.com", phone: "555-0102" },
  { name: "Carlos Lopez", role: :waiter, employee_number: "EMP-003", email: "carlos@cafe.com", phone: "555-0103" },
  { name: "Cocina 1", role: :kitchen, employee_number: "KIT-001", email: "cocina1@cafe.com", phone: nil },
  { name: "Cocina 2", role: :kitchen, employee_number: "KIT-002", email: "cocina2@cafe.com", phone: nil },
  { name: "Admin Principal", role: :admin, employee_number: "ADM-001", email: "admin@cafe.com", phone: "555-0200" }
]

users = users_data.map do |data|
  emp_number = data.delete(:employee_number)

  user = User.create!(
    store: store,
    name: data[:name],
    role: data[:role],
    email: data[:email],
    phone: data[:phone],
    active: true
  )

  Account.create!(
    user: user,
    employee_number: emp_number,
    password: "password123"
  )

  user
end

puts "Created #{users.count} users with accounts (password: password123)"
puts "  Waiters: #{users.count { |u| u.waiter? }}"
puts "  Kitchen: #{users.count { |u| u.kitchen? }}"
puts "  Admin:   #{users.count { |u| u.admin? }}"

# ============================================
# SPOTS (Tables + Takeout)
# ============================================
(1..15).each do |n|
  Spot.create!(store: store, name: "Mesa #{n}", spot_type: :dine_in, position: n, active: true)
end
takeout_spot = Spot.create!(store: store, name: "Para Llevar", spot_type: :takeout, active: true)
puts "Created 15 table spots + 1 takeout spot"

# ============================================
# CATEGORIES
# ============================================
categories_data = [
  { name: "Bebidas Calientes", description: "Hot coffee and espresso drinks", icon: "coffee", position: 1 },
  { name: "Tizanas", description: "Hot fruit teas and infusions", icon: "tea", position: 2 },
  { name: "Crepas Dulces", description: "Sweet crepes with various fillings", icon: "crepe", position: 3 },
  { name: "Especialidades", description: "Chef's special creations", icon: "star", position: 4 },
  { name: "Frappes", description: "Blended iced coffee drinks", icon: "frappe", position: 5 },
  { name: "Postres", description: "Desserts and sweet treats", icon: "cake", position: 6 }
]

categories = {}
categories_data.each do |data|
  cat = Category.create!(data.merge(store: store, active: true))
  categories[cat.name] = cat
end
puts "Created #{categories.count} categories"

# ============================================
# COMPONENTS - Ingredients (price_cents = 0)
# ============================================
ingredients_data = [
  # Coffee ingredients
  { name: "Espresso Shot", description: "Single shot of espresso" },
  { name: "Hot Water", description: "Hot water for Americano" },
  { name: "Steamed Milk", description: "Steamed milk for coffee drinks" },
  { name: "Foam", description: "Milk foam for cappuccino" },
  { name: "Caramel Syrup", description: "Caramel flavored syrup" },
  { name: "Irish Cream Syrup", description: "Irish cream flavored syrup" },
  { name: "Chai Syrup", description: "Chai spice syrup" },
  { name: "Vanilla Syrup", description: "Vanilla flavored syrup" },
  { name: "Whipped Cream", description: "Fresh whipped cream" },

  # Tizanas ingredients
  { name: "Peach Tea Base", description: "Peach flavored tea" },
  { name: "Mango Tea Base", description: "Mango flavored tea" },
  { name: "Guava", description: "Fresh guava" },
  { name: "Cinnamon", description: "Cinnamon stick or powder" },
  { name: "Apple", description: "Apple pieces" },
  { name: "Raisins", description: "Sweet raisins" },
  { name: "Red Fruits Mix", description: "Mixed berries" },

  # Crepe ingredients
  { name: "Crepe Base", description: "Fresh crepe" },
  { name: "Nutella", description: "Chocolate hazelnut spread" },
  { name: "Cajeta", description: "Goat milk caramel" },
  { name: "Lechera", description: "Sweetened condensed milk" },
  { name: "Rompope", description: "Mexican eggnog" },
  { name: "Chantilly Cream", description: "Sweet whipped cream" },

  # Specialty ingredients
  { name: "Banana", description: "Fresh banana slices" },
  { name: "Strawberry", description: "Fresh strawberries" },
  { name: "Walnut", description: "Chopped walnuts" },
  { name: "Chocolate Ice Cream", description: "Chocolate ice cream scoop" },
  { name: "Vanilla Ice Cream", description: "Vanilla ice cream scoop" },
  { name: "Cajeta Sauce", description: "Cajeta caramel sauce" },

  # Frappe ingredients
  { name: "Coffee Frappe Base", description: "Blended coffee base" },
  { name: "Oreo Cookie", description: "Crushed Oreo cookies" },
  { name: "Chocolate Syrup", description: "Chocolate syrup for decoration" },
  { name: "Mocha Base", description: "Chocolate coffee base" }
]

ingredients = {}
ingredients_data.each do |data|
  comp = Component.create!(data.merge(store: store, price_cents: 0, available: true))
  ingredients[comp.name] = comp
end

# ============================================
# COMPONENTS - Extras (price_cents > 0)
# ============================================
extras_data = [
  { name: "Extra Ice Cream", description: "Additional ice cream scoop", price: 20.00 },
  { name: "Extra Strawberries", description: "Additional strawberries", price: 20.00 },
  { name: "Extra Banana", description: "Additional banana", price: 20.00 },
  { name: "Extra Walnut", description: "Additional walnuts", price: 20.00 },
  { name: "Extra Nutella", description: "Extra Nutella filling", price: 15.00 },
  { name: "Extra Whipped Cream", description: "Extra whipped cream", price: 10.00 },
  { name: "Extra Espresso Shot", description: "Additional espresso shot", price: 15.00 },
  { name: "Extra Caramel", description: "Extra caramel drizzle", price: 10.00 },
  { name: "Extra Chocolate", description: "Extra chocolate drizzle", price: 10.00 },
  { name: "Almond Milk", description: "Substitute with almond milk", price: 15.00 },
  { name: "Oat Milk", description: "Substitute with oat milk", price: 15.00 },

  # Crepe-specific filling extras (for second filling)
  { name: "Relleno Extra Nutella", description: "Extra Nutella filling for crepes", price: 10.00 },
  { name: "Relleno Extra Cajeta", description: "Extra Cajeta filling for crepes", price: 10.00 },
  { name: "Relleno Extra Lechera", description: "Extra Lechera filling for crepes", price: 10.00 },
  { name: "Relleno Extra Rompope", description: "Extra Rompope filling for crepes", price: 10.00 }
]

extras = {}
extras_data.each do |data|
  comp = Component.create!(
    store: store,
    name: data[:name],
    description: data[:description],
    price_cents: to_cents(data[:price]),
    available: true
  )
  extras[comp.name] = comp
end

puts "Created #{ingredients.count} ingredients and #{extras.count} extras"

# ============================================
# PRODUCTS - Bebidas Calientes
# ============================================
bebidas_calientes = [
  { name: "Espresso", description: "Rich and bold single shot of espresso", price: 25.00, ingredients: ["Espresso Shot"] },
  { name: "Americano", description: "Espresso with hot water for a smooth, rich flavor", price: 35.00, ingredients: ["Espresso Shot", "Hot Water"] },
  { name: "Cappuccino Caramel", description: "Espresso with steamed milk, foam, and caramel", price: 45.00, ingredients: ["Espresso Shot", "Steamed Milk", "Foam", "Caramel Syrup"] },
  { name: "Cappuccino Irlandes", description: "Espresso with steamed milk, foam, and Irish cream flavor", price: 45.00, ingredients: ["Espresso Shot", "Steamed Milk", "Foam", "Irish Cream Syrup"] },
  { name: "Latte Caramel", description: "Smooth espresso with steamed milk and caramel", price: 60.00, ingredients: ["Espresso Shot", "Steamed Milk", "Caramel Syrup", "Whipped Cream"] },
  { name: "Latte Chai", description: "Spiced chai latte with steamed milk", price: 60.00, ingredients: ["Chai Syrup", "Steamed Milk", "Whipped Cream"] },
  { name: "Latte Chai Vainilla", description: "Chai latte with a touch of vanilla", price: 60.00, ingredients: ["Chai Syrup", "Vanilla Syrup", "Steamed Milk", "Whipped Cream"] }
]

bebidas_calientes.each do |data|
  product = Product.create!(
    store: store,
    category: categories["Bebidas Calientes"],
    name: data[:name],
    description: data[:description],
    base_price_cents: to_cents(data[:price]),
    available: true,
    allows_customization: true
  )

  data[:ingredients].each do |ing_name|
    ProductComponent.create!(product: product, component: ingredients[ing_name], component_type: :ingredient, required: true)
  end

  [extras["Extra Espresso Shot"], extras["Extra Caramel"], extras["Almond Milk"], extras["Oat Milk"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end
end
puts "Created #{bebidas_calientes.count} hot drinks"

# ============================================
# PRODUCTS - Tizanas
# ============================================
tizanas = [
  { name: "Tizana Durazno", description: "Refreshing peach tea infusion", price: 50.00, ingredients: ["Peach Tea Base"] },
  { name: "Tizana Mango", description: "Tropical mango tea infusion", price: 50.00, ingredients: ["Mango Tea Base"] },
  { name: "Ponche de Guayaba", description: "Warm guava punch with cinnamon, apple, and raisins", price: 50.00, ingredients: ["Guava", "Cinnamon", "Apple", "Raisins"] },
  { name: "Tizana Frutos Rojos", description: "Mixed red berries tea infusion", price: 50.00, ingredients: ["Red Fruits Mix"] }
]

tizanas.each do |data|
  product = Product.create!(
    store: store,
    category: categories["Tizanas"],
    name: data[:name],
    description: data[:description],
    base_price_cents: to_cents(data[:price]),
    available: true,
    allows_customization: true
  )

  data[:ingredients].each do |ing_name|
    ProductComponent.create!(product: product, component: ingredients[ing_name], component_type: :ingredient, required: true)
  end
end
puts "Created #{tizanas.count} tizanas"

# ============================================
# PRODUCTS - Crepas Dulces
# 4 individual crepe products, each with its specific filling as required
# Second filling via Relleno Extra components at $10 each
# ============================================
crepe_products = [
  { name: "Crepa de Nutella", description: "Sweet crepe filled with Nutella", filling: "Nutella" },
  { name: "Crepa de Cajeta", description: "Sweet crepe filled with cajeta caramel", filling: "Cajeta" },
  { name: "Crepa de Lechera", description: "Sweet crepe filled with sweetened condensed milk", filling: "Lechera" },
  { name: "Crepa de Rompope", description: "Sweet crepe filled with Mexican eggnog", filling: "Rompope" }
]

crepe_products.each do |data|
  product = Product.create!(
    store: store,
    category: categories["Crepas Dulces"],
    name: data[:name],
    description: data[:description],
    base_price_cents: to_cents(45.00),
    available: true,
    allows_customization: true
  )

  # Required ingredients: Crepe Base + specific filling
  ProductComponent.create!(product: product, component: ingredients["Crepe Base"], component_type: :ingredient, required: true)
  ProductComponent.create!(product: product, component: ingredients[data[:filling]], component_type: :ingredient, required: true)

  # Crepe-specific filling extras (for second filling, $10 each)
  [extras["Relleno Extra Nutella"], extras["Relleno Extra Cajeta"], extras["Relleno Extra Lechera"], extras["Relleno Extra Rompope"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end

  # General extras
  [extras["Extra Ice Cream"], extras["Extra Strawberries"], extras["Extra Banana"], extras["Extra Walnut"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end
end
puts "Created #{crepe_products.count} crepe products"

# ============================================
# PRODUCTS - Especialidades
# ============================================
especialidades = [
  { name: "Cucurumbe", description: "Special crepe with Nutella, banana, strawberry, Chantilly cream, and chocolate ice cream", price: 99.00, ingredients: ["Crepe Base", "Nutella", "Banana", "Strawberry", "Chantilly Cream", "Chocolate Ice Cream"] },
  { name: "Gloria", description: "Special crepe with cajeta sauce, walnuts, and vanilla ice cream", price: 99.00, ingredients: ["Crepe Base", "Cajeta Sauce", "Walnut", "Vanilla Ice Cream"] }
]

especialidades.each do |data|
  product = Product.create!(
    store: store,
    category: categories["Especialidades"],
    name: data[:name],
    description: data[:description],
    base_price_cents: to_cents(data[:price]),
    available: true,
    allows_customization: true
  )

  data[:ingredients].each do |ing_name|
    ProductComponent.create!(product: product, component: ingredients[ing_name], component_type: :ingredient, required: true)
  end

  [extras["Extra Ice Cream"], extras["Extra Strawberries"], extras["Extra Banana"], extras["Extra Walnut"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end
end
puts "Created #{especialidades.count} specialties"

# ============================================
# PRODUCTS - Frappes
# ============================================
frappes = [
  { name: "Oreo Coffee Frappe", description: "Blended coffee with Oreo cookies and chocolate drizzle", price: 75.00, ingredients: ["Coffee Frappe Base", "Oreo Cookie", "Chocolate Syrup"] },
  { name: "Mocha Frappe", description: "Blended chocolate coffee with whipped cream", price: 75.00, ingredients: ["Mocha Base", "Chocolate Syrup", "Whipped Cream"] },
  { name: "Caramel Frappe", description: "Blended coffee with caramel and whipped cream", price: 70.00, ingredients: ["Coffee Frappe Base", "Caramel Syrup", "Whipped Cream"] }
]

frappes.each do |data|
  product = Product.create!(
    store: store,
    category: categories["Frappes"],
    name: data[:name],
    description: data[:description],
    base_price_cents: to_cents(data[:price]),
    available: true,
    allows_customization: true
  )

  data[:ingredients].each do |ing_name|
    ProductComponent.create!(product: product, component: ingredients[ing_name], component_type: :ingredient, required: true)
  end

  [extras["Extra Strawberries"], extras["Extra Chocolate"], extras["Extra Whipped Cream"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end
end
puts "Created #{frappes.count} frappes"

# ============================================
# PRODUCTS - Postres
# ============================================
postres = [
  { name: "Fresas con Crema", description: "Fresh strawberries with sweet cream", price: 65.00, ingredients: ["Strawberry", "Chantilly Cream"] },
  { name: "Waffle Clasico", description: "Crispy waffle with syrup and whipped cream", price: 55.00, ingredients: ["Whipped Cream"] },
  { name: "Waffle con Helado", description: "Waffle topped with ice cream and syrup", price: 75.00, ingredients: ["Vanilla Ice Cream", "Whipped Cream"] }
]

postres.each do |data|
  product = Product.create!(
    store: store,
    category: categories["Postres"],
    name: data[:name],
    description: data[:description],
    base_price_cents: to_cents(data[:price]),
    available: true,
    allows_customization: true
  )

  data[:ingredients].each do |ing_name|
    ProductComponent.create!(product: product, component: ingredients[ing_name], component_type: :ingredient, required: true)
  end

  [extras["Extra Ice Cream"], extras["Extra Strawberries"], extras["Extra Banana"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end
end
puts "Created #{postres.count} desserts"

# ============================================
# PAYMENT METHODS
# ============================================
payment_methods_data = [
  { name: "Efectivo", description: "Cash payment" },
  { name: "Mercado Pago", description: "Mercado Pago QR or app" },
  { name: "Transferencia", description: "Bank transfer" }
]

payment_methods_data.each do |data|
  PaymentMethod.create!(data.merge(store: store, active: true))
end
puts "Created #{payment_methods_data.count} payment methods"

# ============================================
# SAMPLE ORDER (For Testing UI)
# ============================================
puts "\n--- Creating Sample Order ---"

mesa_5 = Spot.find_by(name: "Mesa 5")
waiter = users.find { |u| u.waiter? }

order = Order.create!(
  store: store,
  spot: mesa_5,
  user: waiter,
  status: :open,
  opened_at: Time.current
)

oreo_frappe = Product.find_by(name: "Oreo Coffee Frappe")
cappuccino = Product.find_by(name: "Cappuccino Caramel")
cucurumbe = Product.find_by(name: "Cucurumbe")

# Item 1: Oreo Frappe with half coffee and extra strawberries
item1 = LineItem.create!(
  order: order,
  product: oreo_frappe,
  status: :ordering,
  base_price_cents: oreo_frappe.base_price_cents,
  special_notes: "Extra cold please"
)

LineItemComponent.create!(line_item: item1, component: ingredients["Coffee Frappe Base"], component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
LineItemComponent.create!(line_item: item1, component: ingredients["Oreo Cookie"], component_type: :ingredient, portion: 0.5, unit_price_cents: 0)
LineItemComponent.create!(line_item: item1, component: ingredients["Chocolate Syrup"], component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
LineItemComponent.create!(line_item: item1, component: extras["Extra Strawberries"], component_type: :extra, portion: 1.0, unit_price_cents: to_cents(20.00))
item1.calculate_total!

# Item 2: Cappuccino Caramel (standard)
item2 = LineItem.create!(
  order: order,
  product: cappuccino,
  status: :ordering,
  base_price_cents: cappuccino.base_price_cents
)

cappuccino.product_components.where(component_type: :ingredient).each do |pc|
  LineItemComponent.create!(line_item: item2, component: pc.component, component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
end
item2.calculate_total!

# Item 3: Cucurumbe (standard)
item3 = LineItem.create!(
  order: order,
  product: cucurumbe,
  status: :ordering,
  base_price_cents: cucurumbe.base_price_cents
)

cucurumbe.product_components.where(component_type: :ingredient).each do |pc|
  LineItemComponent.create!(line_item: item3, component: pc.component, component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
end
item3.calculate_total!

order.recalculate_total!

puts "Created sample order: #{order.code}"
puts "  - #{order.line_items.count} items"
puts "  - Total: $#{'%.2f' % order.total}"

# ============================================
# SAMPLE TAKEOUT ORDER
# ============================================
puts "\n--- Creating Sample Takeout Order ---"

americano = Product.find_by(name: "Americano")
latte_caramel = Product.find_by(name: "Latte Caramel")

takeout_order = Order.create!(
  store: store,
  spot: takeout_spot,
  user: waiter,
  status: :open,
  opened_at: Time.current
)

t_item1 = LineItem.create!(
  order: takeout_order,
  product: americano,
  status: :ordering,
  base_price_cents: americano.base_price_cents
)
americano.product_components.where(component_type: :ingredient).each do |pc|
  LineItemComponent.create!(line_item: t_item1, component: pc.component, component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
end
t_item1.calculate_total!

t_item2 = LineItem.create!(
  order: takeout_order,
  product: latte_caramel,
  status: :ordering,
  base_price_cents: latte_caramel.base_price_cents
)
latte_caramel.product_components.where(component_type: :ingredient).each do |pc|
  LineItemComponent.create!(line_item: t_item2, component: pc.component, component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
end
t_item2.calculate_total!

takeout_order.recalculate_total!

puts "Created takeout order: #{takeout_order.code}"
puts "  - #{takeout_order.line_items.count} items"
puts "  - Total: $#{'%.2f' % takeout_order.total}"

# ============================================
# SUMMARY
# ============================================
puts "\n" + "=" * 50
puts "SEED DATA SUMMARY v5.0"
puts "=" * 50
puts "Store: #{store.name}"
puts "Subdomain: #{store.subdomain}.store.com"
puts "Order Prefix: #{store.order_prefix}"
puts ""
puts "Users: #{User.count} (password: password123)"
puts "  - Waiters: #{User.where(role: :waiter).count}"
puts "  - Kitchen: #{User.where(role: :kitchen).count}"
puts "  - Admin:   #{User.where(role: :admin).count}"
puts "Spots: #{Spot.count} (#{Spot.tables.count} tables, #{Spot.takeouts.count} takeout)"
puts "Categories: #{Category.count}"
puts "Products: #{Product.count}"
puts "Components: #{Component.count}"
puts "  - Ingredients: #{ingredients.count}"
puts "  - Extras: #{extras.count}"
puts "Payment Methods: #{PaymentMethod.count}"
puts ""
puts "Sample Order: #{order.code}"
puts "  Items: #{order.line_items.count}"
puts "  Total: $#{'%.2f' % order.total}"
puts "=" * 50
puts "\nSeed complete! Ready for development."

# ============================================
# SECOND STORE (for multi-tenant PWA demo)
# ============================================
store2 = Store.create!(
  name: "Pizzeria Don Mario",
  subdomain: "pizza",
  order_prefix: "PIZ",
  active: true
)
puts "\nCreated second store: #{store2.name} (#{store2.subdomain})"
