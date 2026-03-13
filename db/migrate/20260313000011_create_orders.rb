class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :orders, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true
      t.references :table, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.string :code, null: false
      t.integer :total_cents, default: 0, null: false
      t.text :notes
      t.datetime :opened_at
      t.datetime :cooking_at
      t.datetime :ready_at
      t.datetime :delivered_at
      t.datetime :closed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :orders, [:store_id, :code], unique: true
    add_index :orders, [:store_id, :status]
    add_index :orders, :created_at
  end
end
