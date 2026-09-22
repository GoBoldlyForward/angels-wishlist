# frozen_string_literal: true

class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.references :parent, foreign_key: { to_table: :organizations }
      t.references :primary_contact, foreign_key: { to_table: :users }
      t.references :mailing_address, foreign_key: { to_table: :addresses }

      t.string :name, null: false
      t.string :short_name
      t.string :kind, null: false, default: "chapter"
      t.string :co_brand_line
      t.jsonb  :theme, null: false, default: {}
      t.string :website_url

      # The connected account donations settle into. Chapters only.
      t.string :stripe_account_id

      t.string   :slug
      t.boolean  :active, null: false, default: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
    add_index :organizations, :kind
    add_index :organizations, :deleted_at
  end
end
