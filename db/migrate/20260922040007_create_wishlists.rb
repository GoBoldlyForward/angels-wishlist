# frozen_string_literal: true

class CreateWishlists < ActiveRecord::Migration[8.1]
  def change
    create_table :wishlists do |t|
      t.references :child, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true

      t.string :status, null: false, default: "draft"
      t.string :interests, array: true, null: false, default: []
      t.text   :caregiver_note

      t.datetime :submitted_at
      t.datetime :approved_at

      t.string   :slug
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :wishlists, :slug, unique: true
    add_index :wishlists, :status
    add_index :wishlists, %i[child_id event_id], unique: true
    add_index :wishlists, :deleted_at
  end
end
