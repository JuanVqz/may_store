class CreateOrderCounters < ActiveRecord::Migration[8.1]
  def change
    create_table :order_counters do |t|
      t.references :store, null: false, foreign_key: true
      t.string :year_month, null: false
      t.integer :current_sequence, default: 0, null: false

      t.timestamps
    end

    add_index :order_counters, [:store_id, :year_month], unique: true
  end
end
