class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :role, null: false
      t.string :email
      t.string :phone
      t.boolean :active, default: true, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, [:store_id, :role]
    add_index :users, :deleted_at
  end
end
