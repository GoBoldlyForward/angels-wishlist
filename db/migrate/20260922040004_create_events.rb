# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :organization, null: false, foreign_key: true

      t.string   :name, null: false
      t.datetime :opened_at
      t.datetime :closes_at
      t.datetime :payout_at
      t.integer  :per_child_cap_in_cents, null: false, default: 30_000

      t.string   :slug
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :events, :slug, unique: true
    add_index :events, :deleted_at
  end
end
