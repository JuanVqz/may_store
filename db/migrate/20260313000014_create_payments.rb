class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :payment_method, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.integer :received_cents, default: 0, null: false
      t.text :notes
      t.datetime :paid_at

      t.timestamps
    end

    add_index :payments, [:payment_method_id, :paid_at]
  end
end
