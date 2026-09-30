# frozen_string_literal: true

class ScopeRecordsToChapters < ActiveRecord::Migration[8.1]
  def up
    change_table :organizations, bulk: true do |t|
      t.string :hostname
      t.string :legal_name
      t.string :ein
      t.string :mail_from
      t.integer :platform_fee_basis_points, default: 0, null: false
      t.boolean :stripe_charges_enabled, default: false, null: false
    end
    add_index :organizations, :hostname, unique: true, where: "hostname IS NOT NULL"

    add_reference :categories, :organization, foreign_key: true
    add_reference :catalog_items, :organization, foreign_key: true
    add_column :versions, :organization_id, :bigint
    add_index :versions, :organization_id

    execute <<~SQL
      UPDATE categories SET organization_id = (SELECT id FROM organizations WHERE kind = 'chapter' ORDER BY id LIMIT 1);
      UPDATE catalog_items SET organization_id = categories.organization_id
        FROM categories WHERE categories.id = catalog_items.category_id;
      UPDATE versions SET organization_id = (SELECT id FROM organizations WHERE kind = 'chapter' ORDER BY id LIMIT 1);
    SQL

    change_column_null :categories, :organization_id, false
    change_column_null :catalog_items, :organization_id, false
  end

  def down
    remove_index :versions, :organization_id
    remove_column :versions, :organization_id
    remove_reference :catalog_items, :organization, foreign_key: true
    remove_reference :categories, :organization, foreign_key: true
    remove_index :organizations, :hostname
    change_table :organizations, bulk: true do |t|
      t.remove :hostname, :legal_name, :ein, :mail_from, :platform_fee_basis_points, :stripe_charges_enabled
    end
  end
end
