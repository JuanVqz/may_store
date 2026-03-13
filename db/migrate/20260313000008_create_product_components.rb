class CreateProductComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :product_components do |t|
      t.references :product, null: false, foreign_key: true
      t.references :component, null: false, foreign_key: true
      t.string :component_type, null: false
      t.boolean :required, default: false, null: false
      t.integer :position

      t.timestamps
    end

    add_index :product_components, [:product_id, :component_id, :component_type], unique: true, name: "idx_product_component"
  end
end
