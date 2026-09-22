# frozen_string_literal: true

class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :wishlist, null: false, foreign_key: true
      # Null when the caregiver typed a gift the catalog has no clear match for.
      t.references :catalog_item, foreign_key: true
      # A line is funded whole by one donation, so this reference is what
      # "funded" means. There is no separate status or timestamp for it.
      t.references :donation, foreign_key: true

      t.string  :name, null: false
      # Brand, size or colour. Blank leaves the line in the pool, which any
      # donor funding that gift can cover.
      t.string  :spec
      t.string  :link_url
      t.integer :price_in_cents, null: false

      t.string   :status, null: false, default: "open"
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :line_items, :status
    add_index :line_items, :deleted_at
  end
end
