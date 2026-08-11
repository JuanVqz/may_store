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

    # A corte claims the payments it counts, and counts exactly the payments no
    # corte has claimed yet. Selecting by time window instead would lose any
    # payment written with a paid_at inside an already-closed period: too late
    # for the closed corte, too early for the next one.
    #
    # Null until a corte is closed over it, so the index is partial: the only
    # question ever asked of it is "which payments are still uncounted".
    add_reference :payments, :cash_closing, null: true, foreign_key: true, index: false
    add_index :payments, :cash_closing_id, where: "cash_closing_id IS NULL",
              name: "index_payments_uncounted"
    add_index :payments, [:cash_closing_id, :payment_method_id]
  end
end
