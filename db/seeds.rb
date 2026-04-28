puts "Limpiando datos existentes..."
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

puts "Creando datos iniciales..."

# Auxiliar: convertir pesos a centavos
def to_cents(dollars)
  (dollars * 100).round
end

# ============================================
# TIENDA (Tenant)
# ============================================
store = Store.create!(
  name: "Cafe Delicias",
  subdomain: "cafe",
  order_prefix: "CFE",
  active: true
)
puts "Tienda creada: #{store.name} (#{store.subdomain}.store.com)"

# ============================================
# USUARIOS + CUENTAS
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

puts "Se crearon #{users.count} usuarios con cuentas (contraseña: password123)"
puts "  Meseros: #{users.count { |u| u.waiter? }}"
puts "  Cocina:  #{users.count { |u| u.kitchen? }}"
puts "  Admin:   #{users.count { |u| u.admin? }}"

# ============================================
# LUGARES (Mesas + Para Llevar)
# ============================================
(1..15).each do |n|
  Spot.create!(store: store, name: "Mesa #{n}", spot_type: :dine_in, position: n, active: true)
end
takeout_spot = Spot.create!(store: store, name: "Para Llevar", spot_type: :takeout, active: true)
puts "Se crearon 15 lugares de mesa + 1 lugar para llevar"

# ============================================
# CATEGORÍAS
# ============================================
categories_data = [
  { name: "Bebidas Calientes", description: "Cafés y bebidas de espresso calientes", icon: "coffee", position: 1 },
  { name: "Tizanas", description: "Tés de frutas calientes e infusiones", icon: "tea", position: 2 },
  { name: "Crepas Dulces", description: "Crepas dulces con diversos rellenos", icon: "crepe", position: 3 },
  { name: "Especialidades", description: "Creaciones especiales del chef", icon: "star", position: 4 },
  { name: "Frappes", description: "Bebidas de café frappé", icon: "frappe", position: 5 },
  { name: "Postres", description: "Postres y dulces", icon: "cake", position: 6 }
]

categories = {}
categories_data.each do |data|
  cat = Category.create!(data.merge(store: store, active: true))
  categories[cat.name] = cat
end
puts "Se crearon #{categories.count} categorías"

# ============================================
# COMPONENTES - Ingredientes (price_cents = 0)
# ============================================
ingredients_data = [
  # Ingredientes para café
  { name: "Espresso Shot", description: "Un shot de espresso" },
  { name: "Hot Water", description: "Agua caliente para americano" },
  { name: "Steamed Milk", description: "Leche vaporizada para bebidas de café" },
  { name: "Foam", description: "Espuma de leche para cappuccino" },
  { name: "Caramel Syrup", description: "Jarabe sabor caramelo" },
  { name: "Irish Cream Syrup", description: "Jarabe sabor crema irlandesa" },
  { name: "Chai Syrup", description: "Jarabe de especias chai" },
  { name: "Vanilla Syrup", description: "Jarabe sabor vainilla" },
  { name: "Whipped Cream", description: "Crema batida fresca" },

  # Ingredientes para tizanas
  { name: "Peach Tea Base", description: "Té sabor durazno" },
  { name: "Mango Tea Base", description: "Té sabor mango" },
  { name: "Guava", description: "Guayaba fresca" },
  { name: "Cinnamon", description: "Raja o polvo de canela" },
  { name: "Apple", description: "Trozos de manzana" },
  { name: "Raisins", description: "Pasas dulces" },
  { name: "Red Fruits Mix", description: "Mezcla de frutos rojos" },

  # Ingredientes para crepas
  { name: "Crepe Base", description: "Crepa fresca" },
  { name: "Nutella", description: "Crema de chocolate y avellanas" },
  { name: "Cajeta", description: "Cajeta de leche de cabra" },
  { name: "Lechera", description: "Leche condensada azucarada" },
  { name: "Rompope", description: "Rompope mexicano" },
  { name: "Chantilly Cream", description: "Crema chantilly" },

  # Ingredientes para especialidades
  { name: "Banana", description: "Rebanadas de plátano fresco" },
  { name: "Strawberry", description: "Fresas frescas" },
  { name: "Walnut", description: "Nueces picadas" },
  { name: "Chocolate Ice Cream", description: "Bola de helado de chocolate" },
  { name: "Vanilla Ice Cream", description: "Bola de helado de vainilla" },
  { name: "Cajeta Sauce", description: "Salsa de cajeta" },

  # Ingredientes para frappes
  { name: "Coffee Frappe Base", description: "Base de café frappé" },
  { name: "Oreo Cookie", description: "Galletas Oreo trituradas" },
  { name: "Chocolate Syrup", description: "Jarabe de chocolate para decorar" },
  { name: "Mocha Base", description: "Base de café con chocolate" }
]

ingredients = {}
ingredients_data.each do |data|
  comp = Component.create!(data.merge(store: store, price_cents: 0, available: true))
  ingredients[comp.name] = comp
end

# ============================================
# COMPONENTES - Extras (price_cents > 0)
# ============================================
extras_data = [
  { name: "Extra Ice Cream", description: "Bola de helado adicional", price: 20.00 },
  { name: "Extra Strawberries", description: "Fresas adicionales", price: 20.00 },
  { name: "Extra Banana", description: "Plátano adicional", price: 20.00 },
  { name: "Extra Walnut", description: "Nueces adicionales", price: 20.00 },
  { name: "Extra Nutella", description: "Relleno extra de Nutella", price: 15.00 },
  { name: "Extra Whipped Cream", description: "Crema batida extra", price: 10.00 },
  { name: "Extra Espresso Shot", description: "Shot de espresso adicional", price: 15.00 },
  { name: "Extra Caramel", description: "Hilo de caramelo extra", price: 10.00 },
  { name: "Extra Chocolate", description: "Hilo de chocolate extra", price: 10.00 },
  { name: "Almond Milk", description: "Sustituir con leche de almendra", price: 15.00 },
  { name: "Oat Milk", description: "Sustituir con leche de avena", price: 15.00 },

  # Extras de relleno para crepas (segundo relleno)
  { name: "Relleno Extra Nutella", description: "Relleno extra de Nutella para crepas", price: 10.00 },
  { name: "Relleno Extra Cajeta", description: "Relleno extra de cajeta para crepas", price: 10.00 },
  { name: "Relleno Extra Lechera", description: "Relleno extra de lechera para crepas", price: 10.00 },
  { name: "Relleno Extra Rompope", description: "Relleno extra de rompope para crepas", price: 10.00 }
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

puts "Se crearon #{ingredients.count} ingredientes y #{extras.count} extras"

# ============================================
# PRODUCTOS - Bebidas Calientes
# ============================================
bebidas_calientes = [
  { name: "Espresso", description: "Shot de espresso intenso y robusto", price: 25.00, ingredients: ["Espresso Shot"] },
  { name: "Americano", description: "Espresso con agua caliente para un sabor suave y rico", price: 35.00, ingredients: ["Espresso Shot", "Hot Water"] },
  { name: "Cappuccino Caramel", description: "Espresso con leche vaporizada, espuma y caramelo", price: 45.00, ingredients: ["Espresso Shot", "Steamed Milk", "Foam", "Caramel Syrup"] },
  { name: "Cappuccino Irlandes", description: "Espresso con leche vaporizada, espuma y sabor crema irlandesa", price: 45.00, ingredients: ["Espresso Shot", "Steamed Milk", "Foam", "Irish Cream Syrup"] },
  { name: "Latte Caramel", description: "Espresso suave con leche vaporizada y caramelo", price: 60.00, ingredients: ["Espresso Shot", "Steamed Milk", "Caramel Syrup", "Whipped Cream"] },
  { name: "Latte Chai", description: "Latte de chai especiado con leche vaporizada", price: 60.00, ingredients: ["Chai Syrup", "Steamed Milk", "Whipped Cream"] },
  { name: "Latte Chai Vainilla", description: "Latte de chai con toque de vainilla", price: 60.00, ingredients: ["Chai Syrup", "Vanilla Syrup", "Steamed Milk", "Whipped Cream"] }
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
puts "Se crearon #{bebidas_calientes.count} bebidas calientes"

# ============================================
# PRODUCTOS - Tizanas
# ============================================
tizanas = [
  { name: "Tizana Durazno", description: "Infusión de té de durazno refrescante", price: 50.00, ingredients: ["Peach Tea Base"] },
  { name: "Tizana Mango", description: "Infusión de té de mango tropical", price: 50.00, ingredients: ["Mango Tea Base"] },
  { name: "Ponche de Guayaba", description: "Ponche caliente de guayaba con canela, manzana y pasas", price: 50.00, ingredients: ["Guava", "Cinnamon", "Apple", "Raisins"] },
  { name: "Tizana Frutos Rojos", description: "Infusión de té con mezcla de frutos rojos", price: 50.00, ingredients: ["Red Fruits Mix"] }
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
puts "Se crearon #{tizanas.count} tizanas"

# ============================================
# PRODUCTOS - Crepas Dulces
# 4 crepas individuales, cada una con su relleno específico como requerido
# Segundo relleno vía componentes Relleno Extra a $10 cada uno
# ============================================
crepe_products = [
  { name: "Crepa de Nutella", description: "Crepa dulce rellena de Nutella", filling: "Nutella" },
  { name: "Crepa de Cajeta", description: "Crepa dulce rellena de cajeta", filling: "Cajeta" },
  { name: "Crepa de Lechera", description: "Crepa dulce rellena de lechera", filling: "Lechera" },
  { name: "Crepa de Rompope", description: "Crepa dulce rellena de rompope", filling: "Rompope" }
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

  # Ingredientes requeridos: Base de crepa + relleno específico
  ProductComponent.create!(product: product, component: ingredients["Crepe Base"], component_type: :ingredient, required: true)
  ProductComponent.create!(product: product, component: ingredients[data[:filling]], component_type: :ingredient, required: true)

  # Extras de relleno para crepas (segundo relleno, $10 cada uno)
  [extras["Relleno Extra Nutella"], extras["Relleno Extra Cajeta"], extras["Relleno Extra Lechera"], extras["Relleno Extra Rompope"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end

  # Extras generales
  [extras["Extra Ice Cream"], extras["Extra Strawberries"], extras["Extra Banana"], extras["Extra Walnut"]].each do |extra|
    ProductComponent.create!(product: product, component: extra, component_type: :extra, required: false)
  end
end
puts "Se crearon #{crepe_products.count} crepas"

# ============================================
# PRODUCTOS - Especialidades
# ============================================
especialidades = [
  { name: "Cucurumbe", description: "Crepa especial con Nutella, plátano, fresa, crema chantilly y helado de chocolate", price: 99.00, ingredients: ["Crepe Base", "Nutella", "Banana", "Strawberry", "Chantilly Cream", "Chocolate Ice Cream"] },
  { name: "Gloria", description: "Crepa especial con salsa de cajeta, nueces y helado de vainilla", price: 99.00, ingredients: ["Crepe Base", "Cajeta Sauce", "Walnut", "Vanilla Ice Cream"] }
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
puts "Se crearon #{especialidades.count} especialidades"

# ============================================
# PRODUCTOS - Frappes
# ============================================
frappes = [
  { name: "Oreo Coffee Frappe", description: "Café frappé con galletas Oreo e hilo de chocolate", price: 75.00, ingredients: ["Coffee Frappe Base", "Oreo Cookie", "Chocolate Syrup"] },
  { name: "Mocha Frappe", description: "Café frappé de chocolate con crema batida", price: 75.00, ingredients: ["Mocha Base", "Chocolate Syrup", "Whipped Cream"] },
  { name: "Caramel Frappe", description: "Café frappé con caramelo y crema batida", price: 70.00, ingredients: ["Coffee Frappe Base", "Caramel Syrup", "Whipped Cream"] }
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
puts "Se crearon #{frappes.count} frappes"

# ============================================
# PRODUCTOS - Postres
# ============================================
postres = [
  { name: "Fresas con Crema", description: "Fresas frescas con crema dulce", price: 65.00, ingredients: ["Strawberry", "Chantilly Cream"] },
  { name: "Waffle Clasico", description: "Waffle crujiente con jarabe y crema batida", price: 55.00, ingredients: ["Whipped Cream"] },
  { name: "Waffle con Helado", description: "Waffle con helado y jarabe", price: 75.00, ingredients: ["Vanilla Ice Cream", "Whipped Cream"] }
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
puts "Se crearon #{postres.count} postres"

# ============================================
# MÉTODOS DE PAGO
# ============================================
payment_methods_data = [
  { name: "Efectivo", description: "Pago en efectivo", cash: true },
  { name: "Mercado Pago", description: "QR o app de Mercado Pago" },
  { name: "Transferencia", description: "Transferencia bancaria" }
]

payment_methods_data.each do |data|
  PaymentMethod.create!(data.merge(store: store, active: true))
end
puts "Se crearon #{payment_methods_data.count} métodos de pago"

# ============================================
# ORDEN DE MUESTRA (Para pruebas de UI)
# ============================================
puts "\n--- Creando orden de muestra ---"

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

# Artículo 1: Oreo Frappe con café a la mitad y fresas extra
item1 = LineItem.create!(
  order: order,
  product: oreo_frappe,
  status: :ordering,
  base_price_cents: oreo_frappe.base_price_cents,
  special_notes: "Bien frío por favor"
)

LineItemComponent.create!(line_item: item1, component: ingredients["Coffee Frappe Base"], component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
LineItemComponent.create!(line_item: item1, component: ingredients["Oreo Cookie"], component_type: :ingredient, portion: 0.5, unit_price_cents: 0)
LineItemComponent.create!(line_item: item1, component: ingredients["Chocolate Syrup"], component_type: :ingredient, portion: 1.0, unit_price_cents: 0)
LineItemComponent.create!(line_item: item1, component: extras["Extra Strawberries"], component_type: :extra, portion: 1.0, unit_price_cents: to_cents(20.00))
item1.calculate_total!

# Artículo 2: Cappuccino Caramel (estándar)
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

# Artículo 3: Cucurumbe (estándar)
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

puts "Orden de muestra creada: #{order.code}"
puts "  - #{order.line_items.count} artículos"
puts "  - Total: $#{'%.2f' % order.total}"

# ============================================
# ORDEN PARA LLEVAR DE MUESTRA
# ============================================
puts "\n--- Creando orden para llevar de muestra ---"

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

puts "Orden para llevar creada: #{takeout_order.code}"
puts "  - #{takeout_order.line_items.count} artículos"
puts "  - Total: $#{'%.2f' % takeout_order.total}"

# ============================================
# RESUMEN
# ============================================
puts "\n" + "=" * 50
puts "RESUMEN DE DATOS INICIALES v5.0"
puts "=" * 50
puts "Tienda: #{store.name}"
puts "Subdominio: #{store.subdomain}.store.com"
puts "Prefijo de orden: #{store.order_prefix}"
puts ""
puts "Usuarios: #{User.count} (contraseña: password123)"
puts "  - Meseros: #{User.where(role: :waiter).count}"
puts "  - Cocina:  #{User.where(role: :kitchen).count}"
puts "  - Admin:   #{User.where(role: :admin).count}"
puts "Lugares: #{Spot.count} (#{Spot.tables.count} mesas, #{Spot.takeouts.count} para llevar)"
puts "Categorías: #{Category.count}"
puts "Productos: #{Product.count}"
puts "Componentes: #{Component.count}"
puts "  - Ingredientes: #{ingredients.count}"
puts "  - Extras: #{extras.count}"
puts "Métodos de pago: #{PaymentMethod.count}"
puts ""
puts "Orden de muestra: #{order.code}"
puts "  Artículos: #{order.line_items.count}"
puts "  Total: $#{'%.2f' % order.total}"
puts "=" * 50
puts "\n¡Datos iniciales completos! Listos para desarrollo."

# ============================================
# SEGUNDA TIENDA (para demo multi-tenant)
# ============================================
store2 = Store.create!(
  name: "Pizzeria Don Mario",
  subdomain: "pizza",
  order_prefix: "PIZ",
  active: true
)
puts "\nSegunda tienda creada: #{store2.name} (#{store2.subdomain})"
