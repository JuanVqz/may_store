class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :store, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.integer :base_price_cents, default: 0, null: false
      t.string :image_url
      t.boolean :available, default: true, null: false
      t.boolean :allows_customization, default: true, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :products, [:store_id, :available]
    add_index :products, :deleted_at
  end
end
