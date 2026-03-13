class CreateTables < ActiveRecord::Migration[8.1]
  def change
    create_table :tables do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :tables, [:store_id, :name], unique: true
    add_index :tables, [:store_id, :position]
  end
end
