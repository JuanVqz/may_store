class CreateLineItemComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :line_item_components do |t|
      t.references :line_item, null: false, foreign_key: true
      t.references :component, null: false, foreign_key: true
      t.string :component_type, null: false
      t.decimal :portion, precision: 3, scale: 2, default: 1.0, null: false
      t.integer :unit_price_cents, default: 0, null: false

      t.timestamps
    end
  end
end
