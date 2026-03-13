class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :order_prefix, null: false
      t.string :logo_url
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :stores, :subdomain, unique: true
    add_index :stores, :order_prefix, unique: true
    add_index :stores, :active
  end
end
