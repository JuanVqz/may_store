class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :employee_number, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :accounts, :employee_number
  end
end
