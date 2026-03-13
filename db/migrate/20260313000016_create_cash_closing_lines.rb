class CreateCashClosingLines < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_closing_lines do |t|
      t.references :cash_closing, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.integer :expected_cents, default: 0, null: false
      t.integer :actual_cents, default: 0, null: false
      t.integer :difference_cents, default: 0, null: false

      t.timestamps
    end
  end
end
