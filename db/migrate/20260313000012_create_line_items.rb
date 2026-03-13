class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true
      t.string :status, null: false, default: "ordering"
      t.text :special_notes
      t.integer :base_price_cents, default: 0, null: false
      t.integer :total_price_cents, default: 0, null: false

      t.timestamps
    end

    add_index :line_items, :status
    add_index :line_items, :created_at
  end
end
