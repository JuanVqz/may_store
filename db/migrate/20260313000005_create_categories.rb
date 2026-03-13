class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.string :icon
      t.integer :position
      t.boolean :active, default: true, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :categories, [:store_id, :position]
    add_index :categories, :deleted_at
  end
end
