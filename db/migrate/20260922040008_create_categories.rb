# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string  :name, null: false
      t.string  :icon
      t.string  :tint
      t.string  :headline
      t.text    :blurb
      t.integer :position

      t.string   :slug
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :position
    add_index :categories, :deleted_at
  end
end
