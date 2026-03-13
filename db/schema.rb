# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_13_000016) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "employee_number", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["employee_number"], name: "index_accounts_on_employee_number"
    t.index ["user_id"], name: "index_accounts_on_user_id", unique: true
  end

  create_table "cash_closing_lines", force: :cascade do |t|
    t.integer "actual_cents", default: 0, null: false
    t.bigint "cash_closing_id", null: false
    t.datetime "created_at", null: false
    t.integer "difference_cents", default: 0, null: false
    t.integer "expected_cents", default: 0, null: false
    t.bigint "payment_method_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cash_closing_id"], name: "index_cash_closing_lines_on_cash_closing_id"
    t.index ["payment_method_id"], name: "index_cash_closing_lines_on_payment_method_id"
  end

  create_table "cash_closings", force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.text "notes"
    t.datetime "period_end", null: false
    t.datetime "period_start", null: false
    t.string "status", default: "open", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["store_id", "period_start", "period_end"], name: "idx_on_store_id_period_start_period_end_32eb5e7b9f"
    t.index ["store_id"], name: "index_cash_closings_on_store_id"
    t.index ["user_id"], name: "index_cash_closings_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "description"
    t.string "icon"
    t.string "name", null: false
    t.integer "position"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_categories_on_deleted_at"
    t.index ["store_id", "position"], name: "index_categories_on_store_id_and_position"
    t.index ["store_id"], name: "index_categories_on_store_id"
  end

  create_table "components", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "description"
    t.string "name", null: false
    t.integer "price_cents", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_components_on_deleted_at"
    t.index ["store_id", "available"], name: "index_components_on_store_id_and_available"
    t.index ["store_id"], name: "index_components_on_store_id"
  end

  create_table "line_item_components", force: :cascade do |t|
    t.bigint "component_id", null: false
    t.string "component_type", null: false
    t.datetime "created_at", null: false
    t.bigint "line_item_id", null: false
    t.decimal "portion", precision: 3, scale: 2, default: "1.0", null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["component_id"], name: "index_line_item_components_on_component_id"
    t.index ["line_item_id"], name: "index_line_item_components_on_line_item_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.integer "base_price_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.uuid "order_id", null: false
    t.bigint "product_id", null: false
    t.text "special_notes"
    t.string "status", default: "ordering", null: false
    t.integer "total_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_line_items_on_created_at"
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["product_id"], name: "index_line_items_on_product_id"
    t.index ["status"], name: "index_line_items_on_status"
  end

  create_table "order_counters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_sequence", default: 0, null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.string "year_month", null: false
    t.index ["store_id", "year_month"], name: "index_order_counters_on_store_id_and_year_month", unique: true
    t.index ["store_id"], name: "index_order_counters_on_store_id"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "closed_at"
    t.string "code", null: false
    t.datetime "cooking_at"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.text "notes"
    t.datetime "opened_at"
    t.datetime "ready_at"
    t.string "status", default: "open", null: false
    t.bigint "store_id", null: false
    t.bigint "table_id", null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["store_id", "code"], name: "index_orders_on_store_id_and_code", unique: true
    t.index ["store_id", "status"], name: "index_orders_on_store_id_and_status"
    t.index ["store_id"], name: "index_orders_on_store_id"
    t.index ["table_id"], name: "index_orders_on_table_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id"], name: "index_payment_methods_on_store_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.uuid "order_id", null: false
    t.datetime "paid_at"
    t.bigint "payment_method_id", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["payment_method_id", "paid_at"], name: "index_payments_on_payment_method_id_and_paid_at"
    t.index ["payment_method_id"], name: "index_payments_on_payment_method_id"
  end

  create_table "product_components", force: :cascade do |t|
    t.bigint "component_id", null: false
    t.string "component_type", null: false
    t.datetime "created_at", null: false
    t.integer "position"
    t.bigint "product_id", null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["component_id"], name: "index_product_components_on_component_id"
    t.index ["product_id", "component_id", "component_type"], name: "idx_product_component", unique: true
    t.index ["product_id"], name: "index_product_components_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "allows_customization", default: true, null: false
    t.boolean "available", default: true, null: false
    t.integer "base_price_cents", default: 0, null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "description"
    t.string "image_url"
    t.string "name", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.index ["store_id", "available"], name: "index_products_on_store_id_and_available"
    t.index ["store_id"], name: "index_products_on_store_id"
  end

  create_table "stores", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.string "name", null: false
    t.string "order_prefix", null: false
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_stores_on_active"
    t.index ["order_prefix"], name: "index_stores_on_order_prefix", unique: true
    t.index ["subdomain"], name: "index_stores_on_subdomain", unique: true
  end

  create_table "tables", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "name"], name: "index_tables_on_store_id_and_name", unique: true
    t.index ["store_id", "position"], name: "index_tables_on_store_id_and_position"
    t.index ["store_id"], name: "index_tables_on_store_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.string "role", null: false
    t.bigint "store_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["store_id", "role"], name: "index_users_on_store_id_and_role"
    t.index ["store_id"], name: "index_users_on_store_id"
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "cash_closing_lines", "cash_closings"
  add_foreign_key "cash_closing_lines", "payment_methods"
  add_foreign_key "cash_closings", "stores"
  add_foreign_key "cash_closings", "users"
  add_foreign_key "categories", "stores"
  add_foreign_key "components", "stores"
  add_foreign_key "line_item_components", "components"
  add_foreign_key "line_item_components", "line_items"
  add_foreign_key "line_items", "orders"
  add_foreign_key "line_items", "products"
  add_foreign_key "order_counters", "stores"
  add_foreign_key "orders", "stores"
  add_foreign_key "orders", "tables"
  add_foreign_key "orders", "users"
  add_foreign_key "payment_methods", "stores"
  add_foreign_key "payments", "orders"
  add_foreign_key "payments", "payment_methods"
  add_foreign_key "product_components", "components"
  add_foreign_key "product_components", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "stores"
  add_foreign_key "tables", "stores"
  add_foreign_key "users", "stores"
end
