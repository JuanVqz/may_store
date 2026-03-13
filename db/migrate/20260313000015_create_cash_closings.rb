class CreateCashClosings < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_closings do |t|
      t.references :store, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.datetime :period_start, null: false
      t.datetime :period_end, null: false
      t.text :notes
      t.datetime :closed_at

      t.timestamps
    end

    add_index :cash_closings, [:store_id, :period_start, :period_end]
  end
end
