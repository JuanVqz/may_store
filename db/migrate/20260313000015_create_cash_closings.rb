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

    # One open corte per store, enforced by the database. The whole chain rests on
    # it: two open cortes overlap, both show every unclaimed payment as expected,
    # and whichever closes first claims that money, leaving the other counting a
    # drawer it can never account for. Application-side "reuse the open one" is a
    # read-then-create, which two simultaneous requests can both pass.
    add_index :cash_closings, :store_id, unique: true, where: "status = 'open'",
              name: "index_cash_closings_on_open_per_store"

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
