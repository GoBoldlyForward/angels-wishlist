# frozen_string_literal: true

class CreateCatalogItems < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_items do |t|
      t.references :category, null: false, foreign_key: true

      t.string  :name, null: false
      t.integer :price_in_cents, null: false
      t.integer :min_age
      t.integer :max_age
      t.string  :icon
      t.string  :photo_attribution

      t.boolean  :active, null: false, default: true
      t.string   :slug
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :catalog_items, :slug, unique: true
    add_index :catalog_items, :active
    add_index :catalog_items, :deleted_at
  end
end
