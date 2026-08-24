class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true
      t.string :status, null: false, default: "ordering"
      t.text :special_notes
      t.integer :base_price_cents, default: 0, null: false
      t.integer :total_price_cents, default: 0, null: false
      # Who moved the item, and when. Half a record without the timestamp: the
      # kitchen could say who plated a dish and not how long it sat on the pass,
      # and a cancellation could not be placed in the shift it happened in.
      t.references :ready_by, null: true, foreign_key: { to_table: :users }
      t.datetime :ready_at
      t.references :cancelled_by, null: true, foreign_key: { to_table: :users }
      t.datetime :cancelled_at
      # Why the item was cancelled. Nullable rather than defaulted in the database
      # so "nobody recorded a reason" stays distinguishable from a reason that was
      # actually chosen; LineItem supplies the default when cancelling.
      t.string :cancellation_reason
      t.references :delivered_by, null: true, foreign_key: { to_table: :users }
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :line_items, :status
    add_index :line_items, :created_at
  end
end
