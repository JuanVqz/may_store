class CreateComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :components do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.integer :price_cents, default: 0, null: false
      t.boolean :available, default: true, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :components, [:store_id, :available]
    add_index :components, :deleted_at
  end
end
