# frozen_string_literal: true

class CreatePayouts < ActiveRecord::Migration[8.1]
  def change
    create_table :payouts do |t|
      t.references :household, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      # Snapshot of where a gift card was mailed, so a later address edit
      # does not rewrite history.
      t.references :mailing_address, foreign_key: { to_table: :addresses }

      t.string  :method, null: false, default: "stripe"
      # Defaults to what the household's lists raised. Staff may override it
      # before it is sent, and adjustment_note says why.
      t.integer :amount_in_cents, null: false, default: 0
      t.text    :adjustment_note

      t.string :status, null: false, default: "blocked"
      t.text   :hold_reason

      t.string :stripe_transfer_id
      t.string :gift_card_tracking_number

      t.datetime :scheduled_for
      t.datetime :sent_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :payouts, :status
    add_index :payouts, %i[household_id event_id], unique: true
    add_index :payouts, :deleted_at
  end
end
