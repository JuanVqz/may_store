class CreatePaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_methods do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
