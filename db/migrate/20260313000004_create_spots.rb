class CreateSpots < ActiveRecord::Migration[8.1]
  def change
    create_table :spots do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :spot_type, null: false, default: "dine_in"
      t.integer :position
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :spots, [:store_id, :name], unique: true
    add_index :spots, [:store_id, :position]
    add_index :spots, [:store_id, :spot_type]
  end
end
